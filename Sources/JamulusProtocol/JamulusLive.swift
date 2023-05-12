
import Foundation

///
/// Jamulus connection to a remote server
///
extension JamulusProtocol {
  
  ///
  /// An implementation of the protocol for real live use.
  ///
  public static var live: Self {
    JamulusProtocol(
      open: {
        try await JamulusProtocolActor.shared.open(id: $0, url: $1, kind: $2)
      },
      receive: {
        try await JamulusProtocolActor.shared.receive(id: $0, audioCallback: $1)
      },
      send: { await JamulusProtocolActor.shared.send(id: $0, message: $1) },
      sendAudio: { id, audioData, useSeqNum in
        Task {
          await JamulusProtocolActor.shared.sendAudio(
            id: id,
            audioData: audioData,
            useSeqNumber: useSeqNum
          )
        }
      }
    )
  }
  
  ///
  /// Single live protocol actor instance, keeping track of multiple connections
  ///
  final actor JamulusProtocolActor: GlobalActor {
    static let shared = JamulusProtocolActor()
    
    // Lookup for active connection data
    var connectionData: [String: JamulusProtocolInstance] = [:]
    
    ///
    /// Open a connection to a remote host with a URL
    /// - parameter id - A unique identifer for the connection
    /// - parameter url - URL to connect to
    /// - parameter kind - Type of connection required
    ///
    func open(id: String, url: URL, kind: JamulusConnectionType) async throws
    -> AsyncThrowingStream<JamulusState, Error>  {
      if let _ = connectionData[id] {
        throw JamulusError.connectionAlreadyExists
      }
      
      let instance = try JamulusProtocolInstance(url: url, type: kind)
      self.connectionData[id] = instance
      
      return try await instance.open()
    }
    
    func send(id: String, message: JamulusMessage) async {
      guard let connectionDetails = self.connectionData[id],
            await connectionDetails.state != .disconnecting else { return }
      
      await connectionDetails.send(message)
    }
    
    func sendAudio(id: String, audioData: Data, useSeqNumber: Bool) async {
      guard let connectionDetails = self.connectionData[id],
            await connectionDetails.state != .disconnecting else { return }
      await connectionDetails.sendAudio(audioData, useSeqNumber: useSeqNumber)
    }
    
    func receive(id: String, audioCallback: (@Sendable (Data) -> Void)?) async throws
    -> AsyncThrowingStream<JamulusMessage, Error> {

      guard let connectionDetails = self.connectionData[id] else {
        throw JamulusError.noConnection(nil)
      }
      return try await connectionDetails.receive(audioCallback: audioCallback)
    }
  }
}
