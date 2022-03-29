
import Combine
import Foundation
import Network
import UdpConnection

///
/// Jamulus connection to a remote server
///
extension JamulusProtocol {
  
  ///
  /// An implementation of the protocol for real live use.
  ///
  public static func live(
    url: URL,
    serverKind: ConnectionKind,
    queue: DispatchQueue = .global(qos: .userInteractive)) -> JamulusProtocol? {
      
      guard let connection = UdpConnection.live(url: url, queue: queue) else {
        assertionFailure("Failed to open network connection")
        return nil
      }
      
      // Maintain packet sequence
      var packetSequence: UInt8 = 0 // For UDP reconstruction
      var packetSequenceNext: UInt8 { nextSequenceNumber(val: &packetSequence) }
      var audioPacketSequence: UInt8 = 0 // For UDP reconstruction
      var audioPacketSequenceNext: UInt8 { nextSequenceNumber(val: &audioPacketSequence) }
      
      // Retransmit un-acked packets
      var ackRequiredPackets = [TimeInterval: (seq: UInt8, message: JamulusMessage)]()
      var retransmitPeriodic: AnyCancellable?
      
      // Last seen packet time and state
      var lastPingSent: TimeInterval = 0
      var lastPingReceived: TimeInterval = 0
      var keepAlive: AnyCancellable?
      let statePublisher = PassthroughSubject<JamulusState, JamulusError>()
  
      return JamulusProtocol(
        open: { chanInfo in

          // On the underlying UDP connection, start a keep alive for state
          connection.statePublisher
            .handleEvents(
              receiveSubscription: { _ in
                
              },
              receiveCancel: {
                keepAlive?.cancel()
              }
            )
            .mapError({ JamulusError.networkError($0) })
            .map({ nwState in
              switch nwState {

              case .setup:
                break
                
              case .waiting(_):
                break
                
              case .preparing:
                break
                
              case .ready:
                keepAlive = Timer.publish(every: 1, on: .main, in: .default)
                  .autoconnect()
                  .sink { _ in
                    guard Date().timeIntervalSince1970 < lastPingReceived + 15 else {
                      // No connection
                      statePublisher.send(.disconnected)
                      return
                    }
                    
                    switch serverKind {
                    case .mainServer:
                      connection.send(
                        messageToData(message: .ping(),
                                      nextSeq: packetSequenceNext))
                      lastPingSent = Date().timeIntervalSince1970
                    case .listing:
                      connection.send(
                        messageToData(message: .pingPlusClientCount(),
                                      nextSeq: packetSequenceNext))
                      lastPingSent = Date().timeIntervalSince1970
                      
                    case .directoryLookup:
                      break
                    }
                  }
                
              case .failed(let error):
                statePublisher.send(
                  completion: .failure(JamulusError.networkError(error))
              )
              case .cancelled:
                break
                
              default:
                break
              }
            })
          
          defer {
            statePublisher.send(.connecting)
          }
          return statePublisher.eraseToAnyPublisher()
        },
        receiveDataPublisher: {
          let publisher = PassthroughSubject<JamulusPacket, Never>()
          
          let packetReceiver = connection.receiveDataPublisher
            .handleEvents(
              receiveSubscription: { _ in
                retransmitPeriodic = Timer.publish(every: 2, on: .main, in: .default)
                  .autoconnect()
                  .sink { _ in
                    //
                    
                    // Handle any retransmit of un-acked packets
                    let now = Date().timeIntervalSince1970
                    let packetKeys = ackRequiredPackets.keys.sorted()
                      .filter({ $0 < now - ApiConsts.retransmitTimeout })
                    for key in packetKeys {
                      if let packet = ackRequiredPackets[key] {
                        connection.send(
                          messageToData(message: packet.message,
                                        nextSeq: packet.seq)
                        )
                      }
                    }
                    // TODO: Remove stale i.e. more than 10s old?
                  }
              },
              receiveCancel: {
                retransmitPeriodic?.cancel()
              }
            )
            .map({ parseData(data: $0, defaultHost: connection.remoteHost) })
            .sink(
              receiveCompletion: { completion in
                
              },
              receiveValue: { packet in
                
                switch packet {
                case let .ackMessage(ackType, sequenceNumber):
                  // An acked packet should be removed from the retransmit queue
                  let found = ackRequiredPackets.first(where: {
                    $0.value.message.messageId == ackType &&
                    $0.value.seq == sequenceNumber
                  })
                  
                  if let key = found?.key {
                    ackRequiredPackets[key] = nil
                  }
                  
                case .messageNeedingAck(let message, let seq):
                  let ackMessage = JamulusMessage.ack(ackType: message.messageId,
                                                      sequenceNumber: seq)
                  connection.send(
                    messageToData(message: ackMessage,
                                  nextSeq: packetSequenceNext))
                  
                case .messageNoAck(let message):
                  if message.messageId == 1001 { // Ping
                    lastPingReceived = Date().timeIntervalSince1970
                  }
                  
                default:
                  break
                }
                
                // Forward packet up
                publisher.send(packet)
              }
            )
          
          return publisher
            .handleEvents(
              receiveSubscription: { subscriber in
                
              },
              receiveCancel: {
                packetReceiver.cancel()
              })
            .eraseToAnyPublisher()
        }(),
        send: { message in
          let sequenceNumber = packetSequenceNext
          if message.needsAck {
            // Store message, remove when acked
            ackRequiredPackets[Date().timeIntervalSince1970] = (sequenceNumber, message)
          }
          let data = messageToData(message: message, nextSeq: sequenceNumber)
          connection.send(data)
        },
        sendAudio: {
          if $1 {
            var data = $0
            data.append(audioPacketSequenceNext)
            connection.send(data)
          } else {
            connection.send($0)
          }
        }
      )
    }
}

func nextSequenceNumber(val: inout UInt8) -> UInt8 {
  val += 1
  if val == 255 {
    val = 0
  }
  return val
}


/// Get packet data from a JamulusMessage
func messageToData(message: JamulusMessage, nextSeq: UInt8) -> Data {
  // Add zero word header
  var data = Data([0,0])
  // Add Type
  data.append(message.messageId)
  
  // Add sequence number
  if let override = message.sequenceNumberOverride {
    data.append(override)
  } else {
    data.append(nextSeq)
  }
  // Add payload data
  let payload = message.payload
  // Add data length
  data.append(UInt16(payload.count))
  // and data
  data.append(contentsOf: payload)
  
  // Add CRC bytes
  let crc = JamulusMessage.crcFunc(for: data)
  data.append(crc)
  return data
}

/// Parse network data into a jamulus packet
func parseData(data: Data, defaultHost: String) -> JamulusPacket {
  if data.count >= ApiConsts.packetHeaderSize, data[0] == 0, data[1] == 0 {
    var index = 5
    let dataLen: UInt16 = data.numericalValueAt(index: &index)
    
    // Check length
    if data.count == Int(dataLen) + ApiConsts.packetHeaderSize {
      let dataPacket = data.subdata(in: 0..<data.count-2)
      var crcOffset = dataPacket.count
      let crc: UInt16 = data.numericalValueAt(index: &crcOffset)
      // Check validity
      if crc == JamulusMessage.crcFunc(for: dataPacket),
         let message = JamulusMessage.deserialize(from: dataPacket,
                                                  defaultHost: defaultHost) {
        let sequence = data[4]
        
        switch message {
        case .ack(let ackType, let sequenceNumber):
          return .ackMessage(ackType: ackType, sequenceNumber: sequenceNumber)
          
        default:
          break
        }
        return message.needsAck ?
          .messageNeedingAck(message, sequence) :
          .messageNoAck(message)
      }
    }
  } else {
    // Data packet - just push that out to the audio handler
    return .audio(data)
  }
  return .error(JamulusError.invalidPacket(data))
}
