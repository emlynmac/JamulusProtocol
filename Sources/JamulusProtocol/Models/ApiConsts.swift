
import Foundation

public enum ApiConsts {
  public static let sampleRate48kHz: Float64 = 48000
  public static let frameSamples64: UInt32 = 64
  public static let defaultPort: UInt16 = 22124
  public static let packetHeaderSize = 9
  public static let packetHeaderSizeWithoutChecksum = 7
  public static let packetDataStartOffset = packetHeaderSizeWithoutChecksum
  public static let messageIdNoAckStart = 1000   // Don't ack messages above this
  public static let messageIdAckStart = 9
  public static let retransmitTimeout: TimeInterval = 1
  public static let connectionTimeout: TimeInterval = 15
  public static let minJitterBuffer = 1
  public static let defaultJitterBuffer = 10
  public static let maxJitterBuffer = 20
  public static let autoJitterBuffer = maxJitterBuffer + 1
}

///
/// These are the payload sizes for the Opus packets
/// AudioTransportDetails defines the transport for the audio network layer
///
public enum OpusCompressedSize: UInt32 {
  case monoLowQuality = 12
  case monoNormal = 22
  case monoHighQuality = 36
  case monoLowQualityDouble = 25
  case monoNormalDouble = 45
  case monoHighQualityDouble = 82
  
  case stereoLowQuality = 24
  case stereoNormal = 35
  case stereoHighQuality = 73
  case stereoLowQualityDouble = 47
  case stereoNormalDouble = 71
  case stereoHighQualityDouble = 165
}

public struct ChannelPan: Equatable {
  public static let left: UInt16 = 0
  public static let center: UInt16 = UInt16(Int16.max/2)
  public static let right: UInt16 = UInt16(Int16.max)
  
  var pan: UInt16 = ChannelPan.center
}

public enum AudioCodec: UInt16 {
  case raw = 0
  case celt = 1
  case opus = 2
  case opus64 = 3
}

public enum AudioFrameFactor: UInt16 {
  case normal = 1
  case safe = 2
  
  public var frameSize: UInt16 {
    // 64 samples per frame minimum
    return UInt16(ApiConsts.frameSamples64) * rawValue
  }
}

public enum OsType: UInt8, CustomStringConvertible {
  public var description: String {
    switch self {
    case .windows: return "Windows"
    case .macOS: return "macOS"
    case .linux: return "Linux"
    case .android: return "Android"
    case .iOS: return "iOS"
    case .unix: return "UNIX"
    }
  }
  
  case windows = 0
  case macOS = 1
  case linux = 2
  case android = 3
  case iOS = 4
  case unix = 5
}

public enum RecorderState: UInt8 {
    case unknown = 0
    case notInitialized = 1
    case disabled = 2
    case recording = 3
};
