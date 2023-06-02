//
//  ConnectionContext.swift
//  
//
//  Created by Emlyn Bolton on 2023-05-12.
//

import Foundation
import UdpConnection

// Data for the protocol instance
actor JamulusProtocolInstance {
    
  init(url: URL, type: JamulusConnectionType) throws {
    self.connectionType = type
    guard let udpConnection = UdpConnection.live(
      url: url, queue: .global(qos: .userInteractive)
    ) else {
      throw JamulusError.noConnection(url)
    }
    self.connection = udpConnection
  }
   
  var connection: UdpConnection
  let connectionStart = Date()
  var connectionType: JamulusConnectionType
  
  // Protocol helpers
  var keepAlive: Task<Void, Error>?
  var unAckedMessages = [TimeInterval: (seq: UInt8, message: JamulusMessage)]()
  var retransmitQueue: Task<Void, Error>?
  var disconnectTask: Task<Void, Error>?
  
  // Timing and sequencing
  var lastAudioPacketTime: TimeInterval = 0
  var lastPingReceived: TimeInterval = 0
  var lastPingSent: TimeInterval = 0
  var packetSequence: UInt8 = 0
  var packetSequenceNext: UInt8 { nextSequenceNumber(val: &packetSequence) }
  var packetTimestamp: UInt32 { UInt32(Date().timeIntervalSince(connectionStart) * 1000) }
  
  var audioPacketSequence: UInt8 = 0
  var audioPacketSequenceNext: UInt8 { nextSequenceNumber(val: &audioPacketSequence) }
 
  var splitMessages: [UInt16: [Data?]] = [:] // Storage to reassemble split messages
  
  var stateContinuation: AsyncThrowingStream<JamulusState, Error>.Continuation!
  var state: JamulusState = .disconnected(error: nil) {
    didSet {
      if case let .disconnected(error) = state,
         let error {
        stateContinuation.finish(throwing: error)
        return
      }
      stateContinuation.yield(state)
    }
  }
  
  // MARK: - Protocol implementation
  func open() async throws -> AsyncThrowingStream<JamulusState, Error> {
    // Have to use continuation until we have https://github.com/apple/swift-async-algorithms
    return AsyncThrowingStream<JamulusState, Error> { continuation in
      self.stateContinuation = continuation
      let task = Task {
#if DEBUG
        print("UdpConnection open task started")
#endif
        for await value in connection.connectionState {
#if DEBUG
          print("UdpConnection state: \(value)")
#endif
          switch value {
          case .ready:
            state = .connecting

            if connectionType != .mainServer {
              state = .connected(clientId: nil)
            }
            startHeatbeatTask()
            
          case .waiting(let error),
              .failed(let error):
            state = .disconnected(error: JamulusError.networkError(error))
            
          case .cancelled:
            state = .disconnected()
            
          default:
            break
          }
        } // Await loop on UDPConnection state
#if DEBUG
        print("KeepAlive and connection cancel")
#endif
        keepAlive?.cancel()
        connection.cancel()
      }
      
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
  
  func close() {
    self.connection.cancel()
  }
  
  func send(_ message: JamulusMessage) {
    // Intercept messages for some protocol aspects
    switch message {
    case .disconnect:
      disconnect()
    default:
      break
    }

    let sequenceNumber = packetSequenceNext
    if message.needsAck { // Store message, remove when acked
      unAckedMessages[Date().timeIntervalSince1970] = (sequenceNumber, message)
    }

    let data = messageToData(message: message, nextSeq: sequenceNumber)
    connection.send(data)
  }
  
  func sendAudio(_ audioData: Data, useSeqNumber: Bool) {
    var data = audioData
    if useSeqNumber {
      data.append(audioPacketSequenceNext)
    }
    connection.send(data)
  }
  
  func receive(audioCallback: (@Sendable (Data) -> Void)?) async throws
  -> AsyncThrowingStream<JamulusMessage, Error> {
    startRetransmitQueue()
    return AsyncThrowingStream<JamulusMessage, Error> { continuation in
      Task {
        for try await data in connection.receivedData {
          if let packet = handleReceive(
            packet: parseData(
              data: data,
              defaultHost: connection.remoteHost
            )
          ) {
            switch packet {
            case let .messageNeedingAck(message, _),
              let .messageNoAck(message):
              continuation.yield(message)
              
            case let .audio(data):
              audioCallback?(data)
              
            case .error(_), .ackMessage:
              break
            }
          }
        }
        retransmitQueue?.cancel()
      }
    }
  }
  
  // MARK: - Helper functions
  
  ///
  /// Process a packet from the UdpConnection layer
  /// - parameter packet Jamulus packet to process
  ///
  /// - Returns: packet to forward up, or nil to consume
  ///
  private func handleReceive(packet: JamulusPacket) -> JamulusPacket? {
    switch packet {
    case let .ackMessage(ackType, sequenceNumber):
      handleMessageAck(
        ackType: ackType,
        sequenceNumber: sequenceNumber
      )
      
    case .messageNeedingAck(let message, let seq):
      // Acknowledge the packet
      let ackMessage = JamulusMessage.ack(ackType: message.messageId,
                                          sequenceNumber: seq)
      connection.send(
        messageToData(
          message: ackMessage,
          nextSeq: packetSequenceNext
        )
      )

      switch message {
      case .clientId(id: let id):
        guard state != .disconnecting else { return nil }
        state = .connected(clientId: id)

      case .requestSplitMessagesSupport:
        connection.send(
          messageToData(
            message: .splitMessagesSupport,
            nextSeq: packetSequenceNext
          )
        )
        return nil // Don't send this packet up

      case let .splitMessageContainer(id, totalParts, part, payload):
        if let messageData = handleSplitMessage(
          id: id,
          total: Int(totalParts),
          part: Int(part),
          payload: payload
        ) {
          return handleReceive(
            packet: parseData(
              data: messageData,
              defaultHost: connection.remoteHost
            )
          )
        }
      default: break
      }

    case let .messageNoAck(message):
      switch message {
        
      case let .ping(timeStamp: ts):
        let roundtrip = handlePing(timeStamp: ts)
        return .messageNeedingAck(.ping(timeStamp: roundtrip), 0)

      case let .pingPlusClientCount(clientCount: clientCount,
                                    timeStamp: ts):
        let roundtrip = packetTimestamp - ts
        return .messageNeedingAck(
          .pingPlusClientCount(
            clientCount: clientCount,
            timeStamp: roundtrip),
          0)
      default:
        break
      }

    case .audio:
      if state == .disconnecting {
        lastAudioPacketTime = Date().timeIntervalSince1970
        if self.disconnectTask == nil {
          startDisconnectTask()
        }
        return nil // Don't send this packet up
      }

    default:
      break
    }
    return packet
  }
  
  // Turn the ping into a relative round-trip value for upper layer
  private func handlePing(timeStamp: UInt32) -> UInt32 {
    lastPingReceived = Date().timeIntervalSince1970
    return packetTimestamp - timeStamp
  }
  
  private func handleMessageAck(ackType: UInt16, sequenceNumber: UInt8) {
    // An acked packet should be removed from the retransmit queue
    let found = unAckedMessages.first(where: {
      $0.value.message.messageId == ackType &&
      $0.value.seq == sequenceNumber
    })

    if let key = found?.key {
      unAckedMessages[key] = nil
    }
  }
  
  ///
  /// Takes a partial message and stores for reassembly. If a complete message,
  /// emits the data and removes the temporary storage
  ///
  private func handleSplitMessage(
    id: UInt16, total: Int, part: Int,
    payload: Data
  )
  -> Data? {
    if splitMessages[id] != nil {
      assert(part < splitMessages[id]!.count)
      splitMessages[id]?[part] = payload
    } else {
      // No existing reconstruction, start building
      var completePacket = [Data?](repeating: nil, count: total)
      completePacket[part] = payload
      splitMessages[id] = completePacket
    }
    
    if let parts = splitMessages[id] {
      var message = Data()
      for part in parts {
        guard part != nil else { return nil }
        message.append(part)
      }
      splitMessages.removeValue(forKey: id)
      return message
    }
    
    return nil
  }
  
  private func disconnect() {
    state = .disconnecting
    lastAudioPacketTime = Date().timeIntervalSince1970
    unAckedMessages.removeAll()
    splitMessages.removeAll()
    keepAlive?.cancel()
    retransmitQueue?.cancel()
  }
  
  private func startHeatbeatTask() {
    self.keepAlive = Task {
      while !Task.isCancelled {
        switch state {
          
        case .connecting, .connected(_), .disconnected(_):
          guard lastPingReceived == 0 ||
                  lastPingReceived < lastPingSent +
                  ApiConsts.connectionTimeout else { // No connection
            state = .disconnected(error: .connectionTimedOut)
            return
          }
          
          switch connectionType {
            
          case .mainServer:
            connection.send(
              messageToData(
                message: .ping(
                  timeStamp: packetTimestamp
                ),
                nextSeq: packetSequenceNext
              )
            )
            lastPingSent = Date().timeIntervalSince1970
            
          case .listing:
            connection.send(
              messageToData(
                message: .pingPlusClientCount(
                  clientCount: 0, timeStamp: packetTimestamp
                ),
                nextSeq: packetSequenceNext
              )
            )
            lastPingSent = Date().timeIntervalSince1970
            
          case .directoryLookup:
            break
          }
          
        case .disconnecting:
          if lastAudioPacketTime + 3 < Date().timeIntervalSince1970 {
            state = .disconnected(error: nil)
          }
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)
      }
    }
  }
  
  private func startDisconnectTask() {
    self.disconnectTask = Task {
      while !Task.isCancelled {
        let now = Date().timeIntervalSince1970
        if now - lastAudioPacketTime < 0.2 {
          // Keep sending a disconnect message until the audio stops
          connection.send(
            messageToData(
              message: .disconnect,
              nextSeq: packetSequenceNext
            )
          )
          try? await Task.sleep(nanoseconds: 300000)
        } else {
          state = .disconnected()
          break
        }
      }
    }
  }
  
  private func startRetransmitQueue() {
    self.retransmitQueue = Task {
      while !Task.isCancelled {
        // Handle any retransmit of un-acked packets
        let now = Date().timeIntervalSince1970
        let packetKeys = unAckedMessages.keys
          .sorted()
          .filter({ $0 < now - ApiConsts.retransmitTimeout })
        
        // Remove any old un-acked packets
        let staleKeys = packetKeys.filter({ $0 < now - 10 })
        staleKeys.forEach { key in
          unAckedMessages.removeValue(forKey: key)
        }
        
        // Retransmit un-acked packets
        for key in packetKeys {
          if let packet = unAckedMessages[key] {
            connection.send(
              messageToData(
                message: packet.message,
                nextSeq: packet.seq
              )
            )
          }
        }
        try await Task.sleep(nanoseconds: 2_000_000_000)
      }
    }
  }
}
