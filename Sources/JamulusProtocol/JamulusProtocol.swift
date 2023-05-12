
import Dependencies
import Foundation

///
/// API to make a connection to a Jamulus server endpoint
///
public struct JamulusProtocol {
  ///
  /// Open a connection to a remote host of a particular kind
  /// - Parameter id a unique identifier for this connection
  /// - Parameter url a URL defining the remote host
  /// - Parameter kind a `ConnectionKind` defining the type of the connection
  ///
  /// - Returns a stream of `JamulusState` for the state of the connection
  ///
  public var open: @Sendable (String, URL, JamulusConnectionType) async throws
  -> AsyncThrowingStream<JamulusState, Error>
  
  ///
  /// Receive stream for protocol messages.
  /// - Parameter id the unique identifier for this connection
  /// - Parameter audioReceive a closure to handle audio packets from the protocol layer
  ///
  /// - Returns a stream  of `JamulusMessage` objects as they arrive from the network
  ///
  public var receive: @Sendable (String, (@Sendable (Data) -> Void)?) async throws
  -> AsyncThrowingStream<JamulusMessage, Error>
  
  ///
  /// Sends a message to the remote host.
  /// - Parameter id the unique identifier for this connection
  /// - Parameter message the `JamulusMessage` to send
  ///
  public var send: @Sendable (String, JamulusMessage) async -> Void
  
  ///
  /// Send audio to the remote host
  /// - Parameter id the unique identifier for this connection
  /// - Parameter audioData encoded audio data to send
  /// - Parameter useSequenceNumber whether to append a sequence number to the data
  ///
  public var sendAudio: @Sendable (String, Data, Bool) -> Void
}

///
/// Different connection types require different protocol behaviour.
/// Normal usage is mainServer
///
public enum JamulusConnectionType: Equatable {
  case mainServer       // Audio and signalling connection
  case directoryLookup  // View servers registered there
  case listing          // Just to view server details
}

///
/// Protocol connectivity state
///
public enum JamulusState: Equatable {
  case connecting
  case connected(clientId: UInt8? = nil)
  case disconnecting
  case disconnected(error: JamulusError? = nil)
}

// MARK: Enable Dependency lookup
private enum JamulusProtocolKey: DependencyKey {
  static let liveValue: JamulusProtocol = .live
}

///
/// See https://github.com/pointfreeco/swift-dependencies for usage details
///
public extension DependencyValues {
  var jamulusProtocol: JamulusProtocol {
    get { self[JamulusProtocolKey.self] }
    set { self[JamulusProtocolKey.self] = newValue }
  }
}
