import XCTest

@testable import JamulusProtocol

final class JamulusProtocolTests: XCTestCase {
    func testConstruction() throws {
      
      let test = JamulusProtocol.init(
        open: { id, url, kind in
          AsyncThrowingStream {
            JamulusState.connected(clientId: 69)
          }
        },
        close: { id in
          // Disconnect
          // Cleanup the connection
        },
        receive: { id, audioCallback in
          AsyncThrowingStream(
            unfolding: {
              .clientList(
                channelInfo: []
              )
            }
          )
        },
        send: { id, message in
          print("Received message: \(message)")
        },
        sendAudio: { id, data, useSeqNumber in
          // Code to get audio and send
        }
      )
      
      XCTAssertNotNil(test)
    }
  
  func testLiveConstruction() async throws {
    let live = JamulusProtocol.live
    XCTAssertNotNil(live)
  }
}
