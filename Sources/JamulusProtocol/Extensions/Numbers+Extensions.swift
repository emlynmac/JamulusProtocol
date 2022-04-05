
import Foundation

extension Double {
  ///
  /// Gain and pan messages use a value from 0-32768
  /// This var converts to that range from a normalized value
  ///
  public var deNormalizedAsJamulus: UInt16 {
    UInt16(self * Double(Int16.max))
  }
}

extension UInt16 {
  ///
  /// Gain and pan messages use a value from 0-32768
  /// This var converts to a normalized value
  ///
  public var normalizedFromJamulus: Double {
    return Double(self) / Double(Int16.max)
  }
}

extension UInt8 {
  ///
  /// Jamulus uses 4 bits only to send VU meter level approximations
  ///
  public var normalizedJamulusChannelLevel: Double {
    return Double(self) / Double(14)
  }
}
