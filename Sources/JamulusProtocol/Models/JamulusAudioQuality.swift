
import Foundation

public enum JamulusAudioQuality: String, CaseIterable, Hashable, Sendable {
  case low
  case normal
  case high

  public static func from(_ transDetails: AudioTransportDetails) -> Self {
    switch transDetails.opusPacketSize {
    case .monoNormal, .stereoNormal,
        .monoNormalDouble, .stereoNormalDouble:
      return .normal
    case .monoLowQuality, .stereoLowQuality,
        .monoLowQualityDouble, .stereoLowQualityDouble:
      return .low
    case .monoHighQuality, .stereoHighQuality,
        .monoHighQualityDouble, .stereoHighQualityDouble:
      return .high
    }
  }
}
