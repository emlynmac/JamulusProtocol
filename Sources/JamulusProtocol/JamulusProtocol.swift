
import Combine
import Foundation
import Network

///
/// API to make a connection to a Jamulus server endpoint
///
public struct JamulusProtocol {
  public var open: AnyPublisher<ConnectionState, JamulusError>
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

public struct ConnectionState: Equatable {
  public var state: JamulusState = .disconnected
  var nwState: NWConnection.State
  
  public init(rawValue: NWConnection.State) {
    self.nwState = rawValue
  }
}

public enum JamulusState: Equatable {
  case connecting
  case connected
  case disconnecting
  case disconnected
}

extension JamulusProtocol {
  enum AutoPingType {
    case ping             // Starts a ping publisher
    case pingClientCount  // Starts a ping with client count publisher
    case none
    
    static func initWith(_ kind: ConnectionKind) -> Self {
      switch kind {
      case .mainServer: return .ping
      case .directoryLookup: return .none
      case .listing: return .pingClientCount
      }
    }
  }
}
