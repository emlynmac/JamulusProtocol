import Combine
import XCTest

@testable import JamulusProtocol

final class JamulusProtocolTests: XCTestCase {
    func testExample() throws {
      
      let test = JamulusProtocol.init(
        open: {
          AsyncThrowingStream {
            JamulusState.connected(clientId: 69)
          }
        },
        receivedData: AsyncStream(
          unfolding: {
            .messageNeedingAck(
              .clientList(
                channelInfo: []
              ),
              69
            )
          }),
        send: { message in
          print("Received message: \(message)")
        },
        sendAudio: { _, _ in
          // Code to get audio and send
        }
      )
      
      XCTAssertNotNil(test)
    }
}
