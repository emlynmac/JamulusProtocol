
import Combine
import Foundation
import Network

///
/// API to make a connection to a Jamulus server endpoint
///
public struct JamulusProtocol {
  
  public var open: (ChannelInfo) -> AnyPublisher<JamulusState, JamulusError>
  public var receiveDataPublisher: AnyPublisher<JamulusPacket, Never>
  public var send: (JamulusMessage) -> Void
  public var sendAudio: (Data, Bool) -> Void
}

public enum ConnectionKind {
  case mainServer       // Audio and signalling connection
  case directoryLookup  // View servers registered there
  case listing          // Just to view server details
}

public enum JamulusPacket: Equatable {
  case ackMessage(ackType: UInt16, sequenceNumber: UInt8)
  case messageNeedingAck(JamulusMessage, UInt8)
  case messageNoAck(JamulusMessage)
  case audio(Data)
  case error(JamulusError)
}

public enum JamulusState: Equatable {
  case connecting
  case connected(clientId: UInt8)
  case disconnecting
  case disconnected(error: JamulusError? = nil)
}

/// CRC value for jamulus messaging packets
func jamulusCrc(for data: Data) -> UInt16 {
  let polyNomial: UInt32 = 0x00001020
  var result: UInt32 = ~0
  for byte in data {
    for i in 0..<8 {
      result <<= 1
      if (result & 0x10000) > 0 { result |= 1 }
      if (byte & (1 << (7 - i) )) > 0 { result ^= 1 }
      if (result & 1) > 0 { result ^= polyNomial }
    }
  }
  result = ~result
  return UInt16(result & 0xFFFF)
}
