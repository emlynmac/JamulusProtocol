
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
      var unAckedMessages = [TimeInterval: (seq: UInt8, message: JamulusMessage)]()
      var retransmitPeriodic: AnyCancellable?
      
      // Last seen packet time and state
      var lastPingSent: TimeInterval = 0
      var lastPingReceived: TimeInterval = 0
      var lastAudioPacketTime: TimeInterval = 0
      
      // Protocol state management
      var keepAlive: AnyCancellable?
      let statePublisher = PassthroughSubject<JamulusState, JamulusError>()
      var protocolState = JamulusState.disconnected(error: nil) {
        didSet { statePublisher.send(protocolState) }
      }
      
      // Storage to reassemble split messages
      var splitMessages: [UInt16: [Data?]] = [:]
      
      ///
      /// Process a packet from the UdpConnection layer
      ///
      /// - Returns: true if the packet should be published out of the stack
      func handleReceive(packet: JamulusPacket) -> Bool {
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
            guard protocolState != .disconnecting else { return false }
            protocolState = .connected(clientId: id)
            
          case .requestSplitMessagesSupport:
            connection.send(
              messageToData(
                message: .splitMessagesSupport,
                nextSeq: packetSequenceNext
              )
            )
            return false // Don't send this packet up
            
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
          if message.messageId == 1001 { // Ping
            lastPingReceived = Date().timeIntervalSince1970
          }
          
        case .audio:
          if protocolState == .disconnecting {
            // Keep sending a disconnect message until the audio stops
            lastAudioPacketTime = Date().timeIntervalSince1970
            connection.send(
              messageToData(
                message: .disconnect,
                nextSeq: packetSequenceNext)
            )
          }
        default:
          break
        }
        return true
      }
      
      
      return JamulusProtocol(
        open: {           
          // Monitor the underlying UDP connection
          let connectionState = connection.statePublisher
            .handleEvents(
              receiveCancel: {
#if DEBUG
                print("UdpConnection state publisher cancelled")
#endif
                keepAlive?.cancel()
              }
            )
            .mapError({ JamulusError.networkError($0) })
            .sink(
              receiveCompletion: { result in
#if DEBUG
                print("UdpConnection completed: \(result)")
#endif
                switch result {
                case .finished: break
                case .failure(let error): protocolState = .disconnected(error: error)
                }
              },
              receiveValue: { value in
#if DEBUG
                print("UdpConnection state: \(value)")
#endif
                switch value {
                  
                case .ready:
                  protocolState = .connecting
                  if serverKind != .mainServer {
                    protocolState = .connected()
                  }
                  keepAlive = Timer.publish(every: 1, on: .main, in: .default)
                    .autoconnect()
                    .sink { _ in
                      switch protocolState {
                        
                      case .connecting, .connected(_), .disconnected(_):
                        guard lastPingReceived == 0 ||
                                lastPingReceived < lastPingSent +
                                ApiConsts.connectionTimeout else { // No connection
                          statePublisher.send(.disconnected(error: .connectionTimedOut))
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
                        
                      case .disconnecting:
                        if lastAudioPacketTime + 0.5 < Date().timeIntervalSince1970 {
                          protocolState = .disconnected()
                        }
                      }
                    }
                  
                case .failed(let error):
                  let jamError = JamulusError.networkError(error)
                  protocolState = .disconnected(error: jamError)
                  statePublisher.send(
                    completion: .failure(jamError)
                  )
                  
                case .cancelled:
                  protocolState = .disconnected()
                  break
                  
                default:
                  break
                }
              })
          
          // Return the jamulus state publisher
          return statePublisher
            .handleEvents(
              receiveCancel: {
#if DEBUG
                print("JamulusProtocol statePublisher cancelled")
#endif
                connectionState.cancel()
              }
            )
            .eraseToAnyPublisher()
        },
        receiveDataPublisher: {
          let publisher = PassthroughSubject<JamulusPacket, Never>()
          
          let packetReceiver = connection.receiveDataPublisher
            .handleEvents(
              receiveSubscription: { _ in
                retransmitPeriodic = Timer.publish(every: 2, on: .main, in: .default)
                  .autoconnect()
                  .sink { _ in
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
                if handleReceive(packet: packet) {
                  // Forward packet up
                  publisher.send(packet)
                }
              }
            )
          
          return publisher
            .handleEvents(
              receiveSubscription: { subscriber in
                
              },
              receiveCancel: {
#if DEBUG
                print("JamulusProtocol receive publisher cancelled")
#endif
                packetReceiver.cancel()
              })
            .eraseToAnyPublisher()
        }(),
        send: { message in
          guard protocolState != .disconnecting else { return }
          
          // Intercept messages for some protocol aspects
          switch message {
          case .disconnect:
            protocolState = .disconnecting
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
        sendAudio: {
          guard protocolState != .disconnecting else { return }
          
          if $1 {
//            var data = $0
//            data.append(audioPacketSequenceNext)
//            connection.send(data)
//          } else {
            connection.send($0)
          }
        }
      )
    }
}
