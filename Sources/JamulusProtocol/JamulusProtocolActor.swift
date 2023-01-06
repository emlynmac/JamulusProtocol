import Foundation
import UdpConnection

actor JamulusProtocolActor {
  
  private var connection: UdpConnection
  private var serverKind: ConnectionKind
  private var state: JamulusState = .disconnected(error: nil) {
    didSet {
      if case let .disconnected(error) = state,
         let error {
        stateContinuation?.finish(throwing: error)
        return
      }
      stateContinuation?.yield(state)
    }
  }
  
  private var keepAlive: Task<Void, Error>?
  private var stateStream: AsyncThrowingStream<JamulusState, Error>?
  private var stateContinuation: AsyncThrowingStream<JamulusState, Error>.Continuation?
  
  private var packetSequence: UInt8 = 0
  private var packetSequenceNext: UInt8 {
    nextSequenceNumber(val: &packetSequence)
  }
  private var audioPacketSequence: UInt8 = 0
  private var audioPacketSequenceNext: UInt8 {
    nextSequenceNumber(val: &audioPacketSequence)
  }
  
  // Retransmit un-acked packets
  private var unAckedMessages = [TimeInterval: (seq: UInt8, message: JamulusMessage)]()
  
  // Connection time
  let connectionStart = Date()
  var packetTimestamp: UInt32 {
    UInt32(Date().timeIntervalSince(connectionStart) * 1000)
  }
  
  // Last seen packet time and state
  private var lastPingSent: TimeInterval = 0
  private var lastPingReceived: TimeInterval = 0
  private var lastAudioPacketTime: TimeInterval = 0
  
  // Storage to reassemble split messages
  private var splitMessages: [UInt16: [Data?]] = [:]
  
  init?(
    url: URL,
    serverKind: ConnectionKind,
    receiveQueue: DispatchQueue
  ) {
    guard let connection = UdpConnection.live(url: url, queue: receiveQueue) else {
      assertionFailure("Failed to open network connection")
      return nil
    }
    self.connection = connection
    self.serverKind = serverKind
  }
  
  deinit {
    print("Protocol deinit")
  }
  
  private func open() -> AsyncThrowingStream<JamulusState, Error> {
#if DEBUG
    print("UdpConnection open called")
#endif
    
    if let existing = stateStream {
#if DEBUG
      print("existing connection found...")
#endif
      return existing
    }
    
    stateStream = AsyncThrowingStream<JamulusState, Error> { continuation in
      stateContinuation = continuation
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
            if self.serverKind != .mainServer {
              state = .connected(clientId: nil)
            }
            keepAlive = startConnectionHeartbeat()
            
          case .waiting(let error),
              .failed(let error):
            state = .disconnected(
              error: JamulusError.networkError(error)
            )
            
          case .cancelled:
            state = .disconnected()
            break
            
          default:
            break
          }
          
        } // Await loop on the connection state
        
        print("KeepAlive and connection cancel")
        keepAlive?.cancel()
        connection.cancel()
      }
      
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
    return stateStream!
  }
  
  ///
  /// Process a packet from the UdpConnection layer
  ///
  /// - Returns: packet to forward up, or nil to consume
  private func handleReceive(packet: JamulusPacket) -> JamulusPacket? {
    switch packet {
    case let .ackMessage(ackType, sequenceNumber):
      // An acked packet should be removed from the retransmit queue
      let found = unAckedMessages.first(where: {
        $0.value.message.messageId == ackType &&
        $0.value.seq == sequenceNumber
      })
      
      if let key = found?.key {
        unAckedMessages[key] = nil
      }
      
    case .messageNeedingAck(let message, let seq):
      // Acknowledge the packet
      let ackMessage = JamulusMessage.ack(ackType: message.messageId,
                                          sequenceNumber: seq)
      connection.send(
        messageToData(message: ackMessage,
                      nextSeq: packetSequenceNext)
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
          id: id, total: Int(totalParts), part: Int(part),
          payload: payload, storage: &splitMessages) {
          
          return handleReceive(
            packet: parseData(data: messageData,
                              defaultHost: connection.remoteHost)
          )
        }
        
      default: break
      }
      
    case .messageNoAck(let message):
      switch message {
        // Turn the ping into a relative round-trip value for upper layer
      case .ping(timeStamp: let ts):
        lastPingReceived = Date().timeIntervalSince1970
        
        let roundtrip = packetTimestamp - ts
        return .messageNeedingAck(.ping(timeStamp: roundtrip), 0)
        
      case .pingPlusClientCount(clientCount: let clientCount,
                                timeStamp: let ts):
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
        let now = Date().timeIntervalSince1970
        if now - lastAudioPacketTime < 0.2 {
          // Keep sending a disconnect message until the audio stops
          lastAudioPacketTime = now
          connection.send(
            messageToData(
              message: .disconnect,
              nextSeq: packetSequenceNext)
          )
        } else {
          state = .disconnected()
        }
        return nil // Don't send this packet up
      }
      
    default:
      break
    }
    return packet
  }
}

/// Implementation of the interface
extension JamulusProtocolActor {
  
  var protocolInterface: () -> JamulusProtocol {
    return {
      .init(
        open: self.open,
        receivedData: { [unowned self] in
          let retransmitQueue = self.startRetransmitQueue()
          
          return AsyncStream<JamulusPacket> { continuation in
            Task {
              do {
                for try await data in self.connection.receivedData {
                  if let packet = self.handleReceive(
                    packet: parseData(
                      data: data, defaultHost: self.connection.remoteHost
                    )
                  ) {
                    continuation.yield(packet)
                  }
                }
              } catch {
                print(error)
                // TODO: handle the error!
              }
              retransmitQueue.cancel()
            }
          }
        }(),
        send: { [unowned self] message in
          guard state != .disconnecting else { return }
          
          // Intercept messages for some protocol aspects
          switch message {
            
          case .disconnect:
            state = .disconnecting
            lastAudioPacketTime = Date().timeIntervalSince1970
            unAckedMessages.removeAll()
            splitMessages.removeAll()
            
          default:
            break
          }
          
          let sequenceNumber = packetSequenceNext
          if message.needsAck { // Store message, remove when acked
            unAckedMessages[Date().timeIntervalSince1970] = (sequenceNumber, message)
          }
          let data = messageToData(message: message, nextSeq: sequenceNumber)
          connection.send(data)
        },
        sendAudio: { [unowned self] data, addSequenceNumber in
          guard state != .disconnecting else { return }
          var data = data
          if addSequenceNumber {
            data.append(audioPacketSequenceNext)
          }
          connection.send(data)
        }
      )
    }
  }
  
  private func startRetransmitQueue() -> Task<Void, Error> {
    Task {
      while !Task.isCancelled {
        
        // Handle any retransmit of un-acked packets
        let now = Date().timeIntervalSince1970
        let packetKeys = unAckedMessages.keys.sorted()
          .filter({ $0 < now - ApiConsts.retransmitTimeout })
        
        // Remove any old un-acked packets
        let staleKeys = packetKeys.filter({ $0 < now - 10 })
        staleKeys.forEach({ unAckedMessages.removeValue(forKey: $0) })
        
        // Retransmit un-acked packets
        for key in packetKeys {
          if let packet = unAckedMessages[key] {
            connection.send(
              messageToData(message: packet.message,
                            nextSeq: packet.seq)
            )
          }
        }
        try await Task.sleep(nanoseconds: 2_000_000_000)
      }
    }
  }
  
  private func startConnectionHeartbeat() -> Task<Void, Error> {
    Task {
      while !Task.isCancelled {
        switch state {
          
        case .connecting, .connected(_), .disconnected(_):
          guard lastPingReceived == 0 ||
                  lastPingReceived < lastPingSent +
                  ApiConsts.connectionTimeout else { // No connection
            state = .disconnected(error: .connectionTimedOut)
            return
          }
          
          switch serverKind {
            
          case .mainServer:
            connection.send(
              messageToData(message: .ping(timeStamp: packetTimestamp),
                            nextSeq: packetSequenceNext))
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
}
