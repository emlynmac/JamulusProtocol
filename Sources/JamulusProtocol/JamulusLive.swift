
import Combine
import Foundation
import Network
import UdpConnection

///
/// Jamulus connection to a remote server
///
extension JamulusProtocol {
  public static func live(
    url: URL,
    serverKind: ConnectionKind,
    queue: DispatchQueue = .global(qos: .userInteractive)) -> JamulusProtocol? {
    let autoPingType = AutoPingType.initWith(serverKind)
    guard let connection = UdpConnection.live(url: url, queue: queue) else {
      assertionFailure("Failed to open network connection")
      return nil
    }
    
    // Maintain packet sequence
    var packetSequence: UInt8 = 0 // For UDP reconstruction
    var packetSequenceNext: UInt8 { nextSequenceNumber(val: &packetSequence) }
    var audioPacketSequence: UInt8 = 0 // For UDP reconstruction
    var audioPacketSequenceNext: UInt8 { nextSequenceNumber(val: &audioPacketSequence) }
    
    // Keep alive for the channel
    var pingCancellable: AnyCancellable?
    
    
    return JamulusProtocol(
      open: connection.statePublisher
        .handleEvents(receiveCancel: {
          pingCancellable?.cancel()
          connection.cancel()
        })
        .mapError({ JamulusError.networkError($0) })
        .map({ ConnectionState(rawValue: $0) })
        .eraseToAnyPublisher(),
      receiveDataPublisher: {
        let publisher = PassthroughSubject<JamulusPacket, Never>()
        
        let packetReceiver = connection.receiveDataPublisher
          .handleEvents(
            receiveSubscription: { _ in
              pingCancellable = Timer.publish(every: 1, on: .main, in: .default)
                .autoconnect()
                .sink { _ in
                  switch autoPingType {
                  case .ping:
                    connection.send(
                      messageToData(message: .ping(),
                                    nextSeq: packetSequenceNext))
                  case .pingClientCount:
                    connection.send(
                      messageToData(message: .pingPlusClientCount(),
                                    nextSeq: packetSequenceNext))
                  case .none:
                    break
                  }
                }
            }
          )
          .map({ parseData(data: $0, defaultHost: connection.remoteHost) })
          .sink(
            receiveCompletion: { completion in
              
            },
            receiveValue: { packet in
              switch packet {
              case .messageNeedingAck(let message, let seq):
                let ackMessage = JamulusMessage.ack(ackType: message.messageId,
                                                    sequenceNumber: seq)
                connection.send(
                  messageToData(message: ackMessage,
                                nextSeq: packetSequenceNext))
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
        if message.needsAck {
          // TODO: track acks / retransmits
        }
        let data = messageToData(message: message, nextSeq: packetSequenceNext)
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
