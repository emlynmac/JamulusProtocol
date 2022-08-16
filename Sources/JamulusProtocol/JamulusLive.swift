
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
    queue: DispatchQueue = .global(qos: .userInteractive)) async -> JamulusProtocol? {
      
      let protocolActor = JamulusProtocolActor(
        url: url,
        serverKind: serverKind,
        receiveQueue: queue
      )
      return await protocolActor?.protocolInterface()
    }
}
