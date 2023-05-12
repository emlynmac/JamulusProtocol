
import Foundation

///
/// Provider of details for the audio transport layer for the jamulus protocol
/// Used to set up the Opus audio coder
///
public struct AudioTransportDetails: Equatable, Sendable {
  
  public init(
    packetSize: OpusCompressedSize = .stereoNormalDouble,
    blockFactor: AudioFrameFactor = .normal,
    channelCount: UInt8 = 2,
    sampleRate: UInt32 = UInt32(ApiConsts.sampleRate48kHz),
    codec: JamulusAudioCodec = .opus,
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
  public var codec: JamulusAudioCodec
  
  /// From jamulus server 3.6.0 onwards, append a byte sequence number to the audio packet
  public var sequenceAudioPackets: Bool
  
  public var frameSize: UInt16 {
    let multiplier: UInt16 = codec == .opus ? 2 : 1
    // 64 samples per frame minimum
    return UInt16(ApiConsts.frameSamples64) * blockFactor.rawValue * multiplier
  }
  
  ///
  /// Provides the bit rate to set for the Opus encoder, based on the size of the coded bytes
  ///
  public func bitRatePerSec() -> Int32 {
    let frameSize = codec == .opus64 ?
    ApiConsts.frameSamples64 : 2 * ApiConsts.frameSamples64
    
    return Int32((sampleRate * opusPacketSize.rawValue * 8) / frameSize )
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
    let codec = JamulusAudioCodec(rawValue: codecVal) ?? .opus
    let flags: UInt16 = data.numericalValueAt(index: &offset)
    
    var opusSize = OpusCompressedSize.stereoNormalDouble
    if let parsed = OpusCompressedSize(rawValue: packetSize) {
      // We parsed one without a sequence number
      opusSize = parsed
    } else if let parsed = OpusCompressedSize(rawValue: packetSize-1) {
      // We parsed one with a sequence number
      opusSize = parsed
    }
    return AudioTransportDetails(
      packetSize: opusSize,
      blockFactor: AudioFrameFactor(rawValue: blockFactor) ?? .normal,
      channelCount: channelCount,
      sampleRate: sampleRate,
      codec: codec,
      counterRequired: flags == 1 ? true : false)
  }
}

extension Data {
  mutating func append(_ value: AudioTransportDetails) {
    var opusSize = value.opusPacketSize.rawValue
    if value.sequenceAudioPackets { opusSize += 1 }  // For sequence
    append(opusSize)
    append(value.blockFactor.rawValue)
    append(value.channelCount)
    append(value.sampleRate)
    append(value.codec.rawValue)
    append(UInt16(value.sequenceAudioPackets ? 1 : 0))
    append(UInt32(0))
  }
}


extension AudioTransportDetails {
  
  // MARK: - 128 frame presets
  ///
  /// Default stereo normal quality
  ///
  public static var stereoNormal: Self {
    .init(
      packetSize: .stereoNormalDouble,
      blockFactor: .normal,
      channelCount: 2,
      sampleRate: UInt32(ApiConsts.sampleRate48kHz),
      codec: .opus,
      counterRequired: true
    )
  }
  
  public static var monoNormal: Self {
    var mono = stereoNormal
    mono.channelCount = 1
    mono.opusPacketSize = .monoNormalDouble
    return mono
  }
  
  public static var stereoHighQuality: Self {
    var high = stereoNormal
    high.opusPacketSize = .stereoHighQualityDouble
    return high
  }
  
  public static var monoHighQuality: Self {
    var mono = monoNormal
    mono.opusPacketSize = .monoHighQualityDouble
    return mono
  }
  
  public static var stereoLowQuality: Self {
    var high = stereoNormal
    high.opusPacketSize = .stereoLowQualityDouble
    return high
  }
  
  public static var monoLowQuality: Self {
    var mono = monoNormal
    mono.opusPacketSize = .monoLowQualityDouble
    return mono
  }
  
  
  // MARK: - 64 frame presets
  
  public static var stereoNormalQuality64: Self {
    .init(
      packetSize: .stereoNormal,
      blockFactor: .normal,
      channelCount: 2,
      sampleRate: UInt32(ApiConsts.sampleRate48kHz),
      codec: .opus64,
      counterRequired: true
    )
  }
  
  public static var monoNormalQuality64: Self {
    var mono = stereoNormalQuality64
    mono.channelCount = 1
    mono.opusPacketSize = .monoNormal
    return mono
  }

  public static var stereoHighQuality64: Self {
    var high = stereoNormalQuality64
    high.opusPacketSize = .stereoHighQuality
    return high
  }
  
  public static var monoHighQuality64: Self {
    var mono = monoNormalQuality64
    mono.opusPacketSize = .monoHighQuality
    return mono
  }
  
  public static var stereoLowQuality64: Self {
    var high = stereoNormalQuality64
    high.opusPacketSize = .stereoLowQuality
    return high
  }
  
  public static var monoLowQuality64: Self {
    var mono = monoNormalQuality64
    mono.opusPacketSize = .monoLowQuality
    return mono
  }
}

extension AudioTransportDetails {
  
  /// Provides an updated transport property details for new settings included
  public func presetWithChanges(newCodec: JamulusAudioCodec) -> Self {
    guard codec != newCodec else { return self }
    
    if channelCount == 1 {
      switch newCodec {
      case .raw, .celt: return self
      case .opus:
        switch opusPacketSize {
        case .monoHighQualityDouble: return .monoHighQuality
        case .monoNormalDouble: return .monoNormal
        default: return .monoNormal
        }
      case .opus64:
        switch opusPacketSize {
        case .monoHighQuality: return .monoHighQuality64
        case .monoNormal: return .monoNormalQuality64
        default: return .monoNormalQuality64
        }
      }
    } else if channelCount == 2 {
      switch newCodec {
      case .raw, .celt: return self
      case .opus:
        switch opusPacketSize {
        case .stereoHighQuality: return .stereoHighQuality
        case .stereoNormal: return .stereoNormal
        default: return .stereoNormal
        }
      case .opus64:
        switch opusPacketSize {
        case .stereoHighQualityDouble: return .stereoHighQuality64
        case .stereoNormalDouble: return .stereoNormalQuality64
        default: return .stereoNormalQuality64
        }
      }
    }
    return self
  }
  
  ///
  /// Returns a new preset with the requested quality
  ///
  public func presetWithChanges(newQuality: JamulusAudioQuality) -> Self {

    switch newQuality {
    case .low:
      if codec == .opus {
        return channelCount == 1 ? .monoLowQuality : .stereoLowQuality
      } else if codec == .opus64 {
        return channelCount == 1 ? .monoLowQuality64 : .stereoLowQuality64
      }
      
    case .normal:
      if codec == .opus {
        return channelCount == 1 ? .monoNormal : .stereoNormal
      } else if codec == .opus64 {
        return channelCount == 1 ? .monoNormalQuality64 : .stereoNormalQuality64
      }
    case .high:
      if codec == .opus {
        return channelCount == 1 ? .monoHighQuality : .stereoHighQuality
      } else if codec == .opus64 {
        return channelCount == 1 ? .monoHighQuality64 : .stereoHighQuality64
      }
    }
    return self
  }
}
