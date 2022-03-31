
import Foundation

extension Double {
  public var deNormalizedAsJamulus: UInt16 {
    UInt16(self * Double(Int16.max))
  }
}

extension UInt16 {
  public var normalizedFromJamulus: Double {
    return Double(self) / Double(Int16.max)
  }
}

extension UInt8 {
  public var normalizedFromJamulus: Double {
    return Double(self) / Double(Int8.max)
  }
}
