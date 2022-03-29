
import Foundation

public struct AudioTransportDetails: Equatable {
  var packetSize: UInt32 = 0
  var blockFactor: UInt16 = AudioFrameFactor.normal.rawValue
  var channelCount: UInt8 = 2
  var sampleRate: UInt32 = UInt32(ApiConsts.sampleRate48kHz)
  var codec: AudioCodec = .opus
  var counterRequired: Bool = false
  
  static func parseFrom(data: Data) -> AudioTransportDetails {
    let kNetTransSize = 19
    assert(data.count == kNetTransSize)
    
    var offset = 0
    let packetSize: UInt32 = data.numericalValueAt(index: &offset)
    let blockFactor: UInt16 = data.numericalValueAt(index: &offset)
    let channelCount: UInt8 = data.numericalValueAt(index: &offset)
    let sampleRate: UInt32 = data.numericalValueAt(index: &offset)
    let codecVal: UInt16 = data.numericalValueAt(index: &offset)
    let codec = AudioCodec(rawValue: codecVal) ?? .raw
    
    return AudioTransportDetails(
      packetSize: packetSize,
      blockFactor: blockFactor,
      channelCount: channelCount,
      sampleRate: sampleRate,
      codec: codec)
  }
}

extension Data {
  mutating func append(_ value: AudioTransportDetails) {
    append(value.packetSize)
    append(value.blockFactor)
    append(value.channelCount)
    append(value.sampleRate)
    append(value.codec.rawValue)
  }
}
