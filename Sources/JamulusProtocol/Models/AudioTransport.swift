
import Foundation

///
/// Provider of details for the audio transport layer for the jamulus protocol
/// Used to set up the Opus audio coder
///
public struct AudioTransportDetails: Equatable {
  
  public init(
    packetSize: OpusCompressedSize = .stereoNormalDouble,
    blockFactor: AudioFrameFactor = .normal,
    channelCount: UInt8 = 2,
    sampleRate: UInt32 = UInt32(ApiConsts.sampleRate48kHz),
    codec: AudioCodec = .opus,
    counterRequired: Bool = true) {
    self.opusPacketSize = packetSize
    self.blockFactor = blockFactor
    self.channelCount = channelCount
    self.sampleRate = sampleRate
    self.codec = codec
    self.sequenceAudioPackets = counterRequired
  }
  
  public var opusPacketSize: OpusCompressedSize
  
  /// For a AudioFrameFactor.single, Opus should be configured with some additional options
  public var blockFactor: AudioFrameFactor
  public var channelCount: UInt8
  public var sampleRate: UInt32
  public var codec: AudioCodec
  
  /// From jamulus server 3.6.0 onwards, append a byte sequence number to the audio packet
  public var sequenceAudioPackets: Bool
  
  ///
  /// Provides the bit rate to set for the Opus encoder,
  ///
  public func bitRatePerSec() -> Int32 {
    let frameSize = codec == .opus64 ?
    ApiConsts.frameSamples64 : 2 * ApiConsts.frameSamples64
    
    return Int32((sampleRate * opusPacketSize.rawValue * 8) / frameSize)
  }
  
  static func parseFrom(data: Data) -> AudioTransportDetails {
    let kNetTransSize = 19
    assert(data.count == kNetTransSize)
    
    var offset = 0
    let packetSize: UInt32 = data.numericalValueAt(index: &offset)
    let blockFactor: UInt16 = data.numericalValueAt(index: &offset)
    let channelCount: UInt8 = data.numericalValueAt(index: &offset)
    let sampleRate: UInt32 = data.numericalValueAt(index: &offset)
    let codecVal: UInt16 = data.numericalValueAt(index: &offset)
    let codec = AudioCodec(rawValue: codecVal) ?? .opus
    let flags: UInt16 = data.numericalValueAt(index: &offset)
    
    return AudioTransportDetails(
      packetSize: OpusCompressedSize(rawValue: packetSize) ?? .stereoNormalDouble,
      blockFactor: AudioFrameFactor(rawValue: blockFactor) ?? .normal,
      channelCount: channelCount,
      sampleRate: sampleRate,
      codec: codec,
      counterRequired: flags == 1 ? true : false)
  }
}

extension Data {
  mutating func append(_ value: AudioTransportDetails) {
    append(value.opusPacketSize.rawValue)
    append(value.blockFactor.rawValue)
    append(value.channelCount)
    append(value.sampleRate)
    append(value.codec.rawValue)
    append(UInt16(value.sequenceAudioPackets ? 1 : 0))
    append(UInt32(0))
  }
}


extension AudioTransportDetails {
  
  ///
  /// Default stereo normal quality
  ///
  public static var stereoNormal: Self {
    .init(packetSize: .stereoNormalDouble,
          blockFactor: .normal,
          channelCount: 2,
          sampleRate: UInt32(ApiConsts.sampleRate48kHz),
          codec: .opus,
          counterRequired: true)
  }
}
