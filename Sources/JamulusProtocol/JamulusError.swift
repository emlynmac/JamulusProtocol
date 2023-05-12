
import Foundation
import Network

public enum JamulusError: CustomStringConvertible, Equatable, Error {
  public var description: String {
    switch self {
    case .avAudioError(let error):
      return error.localizedDescription
    case .audioConversionFailed:
      return "Could not convert audio"
    case .connectionAlreadyExists:
      return "Connection already open"
    case .connectionTimedOut:
      return "Server no longer available"
    case .bufferOverrun:
      return "Network receive buffer overflow"
    case .invalidAudioConfiguration:
      return "Audio configuration invalid"
    case .noInputDevice:
      return "No input device configured"
    case .noOutputDevice:
      return "No output device configured"
    case .invalidPacket:
      return "Packet was not valid"
    case .opusError(let val):
      return "Opus error: \(opusErrorString(val))"
    case .opusNotConfigured:
      return "Opus not configured"
    case .networkError(let nwError):
      return "Network error: \(nwError.localizedDescription)"
    case .noConnection(let url):
      return "Could not connect \(url != nil ? "to \(url!.absoluteString)" : "")"
    case .audioNotPermitted:
      return "You need to permit audio recording in permissions"
    }
  }
  
  case avAudioError(NSError)
  case connectionAlreadyExists
  case connectionTimedOut
  case bufferOverrun
  case invalidAudioConfiguration
  case noInputDevice
  case noOutputDevice
  case invalidPacket(Data)
  case opusError(Int32?)
  case audioConversionFailed
  case opusNotConfigured
  case networkError(NWError)
  case noConnection(URL?)
  case audioNotPermitted

  private func opusErrorString(_ val: Int32?) -> String {
    switch val {
    case 0: return "OK"
    case -1: return "Bad argument"
    case -2: return "Buffer too small"
    case -3: return "Internal error"
    case -4: return "Invalid packet"
    case -5: return "Unimplemented"
    case -6: return "Invalid state"
    case -7: return "Allocation failed"
    default: return "Unknown error \(String(describing: val))"
    }
  }
}
