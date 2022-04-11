
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

extension Float {
  
  ///
  /// Scale a value for VU meter range
  ///
  public func scaledPower(minDb: Float = -80) -> Float {
    guard self.isFinite else { return 0.0 }
     
    if self < minDb { return 0.0 }
    else if self >= 1.0 { return 1.0 }
    return (abs(minDb) - abs(self)) / abs(minDb)
  }
}
