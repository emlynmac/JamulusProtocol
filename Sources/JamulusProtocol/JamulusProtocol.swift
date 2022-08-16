
import Foundation
import Network

///
/// API to make a connection to a Jamulus server endpoint
///
public struct JamulusProtocol {
  public var open: () -> AsyncThrowingStream<JamulusState, Error>
  public var receivedData: AsyncStream<JamulusPacket>
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
  case connected(clientId: UInt8? = nil)
  case disconnecting
  case disconnected(error: JamulusError? = nil)
}
