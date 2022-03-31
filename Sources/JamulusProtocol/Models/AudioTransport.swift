
import Foundation

public struct AudioTransportDetails: Equatable {
  
  public init(
    packetSize: UInt32 = OpusCompressedSize.stereoNormalDouble.rawValue,
    blockFactor: UInt16 = AudioFrameFactor.normal.rawValue,
    channelCount: UInt8 = 2,
    sampleRate: UInt32 = UInt32(ApiConsts.sampleRate48kHz),
    codec: AudioCodec = .opus,
    counterRequired: Bool = false) {
    self.packetSize = packetSize
    self.blockFactor = blockFactor
    self.channelCount = channelCount
    self.sampleRate = sampleRate
    self.codec = codec
    self.counterRequired = counterRequired
  }
  
  public var packetSize: UInt32 = 0
  public var blockFactor: UInt16 = AudioFrameFactor.normal.rawValue
  public var channelCount: UInt8 = 2
  public var sampleRate: UInt32 = UInt32(ApiConsts.sampleRate48kHz)
  public var codec: AudioCodec = .opus
  public var counterRequired: Bool = false
  
  
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
    append(UInt16(value.counterRequired ? 1 : 0))
    append(UInt32(0))
  }
}
