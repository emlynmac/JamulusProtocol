
import Foundation
import Network

public enum JamulusError: CustomStringConvertible, Equatable, Error {
  public var description: String {
    switch self {
    case .connectionTimedOut:
      return "Server no longer available"
    case .bufferOverrun:
      return "Network receive buffer overflow"
    case .invalidAudioConfiguration:
      return "Audio configuration invalid"
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
    }
  }
  
  case connectionTimedOut
  case bufferOverrun
  case invalidAudioConfiguration
  case invalidPacket(Data)
  case opusError(Int32?)
  case opusNotConfigured
  case networkError(NWError)
  case noConnection(URL?)

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
