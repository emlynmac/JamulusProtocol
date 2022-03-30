
import Foundation

extension Data {
  
  /// Strings are UTF8, with either 1 or 2 byte length header
  func jamulusStringAt(index: inout Int, lengthSize: Int = 2) -> String {
    guard index + lengthSize < count else {
      return ""
    }
    
    var stringSize = 0
    if lengthSize == 1 {
      stringSize = Int(self[index])
      index += 1
    } else if lengthSize == 2 {
      let biggerSize: UInt16 = numericalValueAt(index: &index)
      stringSize = Int(biggerSize)
    }
    guard stringSize > 0 else { return "" }
    
    let endOffset = index + Int(stringSize)
    guard (index + Int(stringSize)) <= self.count else {
      assertionFailure("String data not long enough!")
      return ""
    }
    
    let data = subdata(in: index..<endOffset)
    index += data.count
    
    return String(decoding: data, as: UTF8.self)
  }
  
  /// Grabs a value at the index and increments the index to the next available point
  func numericalValueAt<T: Numeric>(index: inout Int) -> T {
    let byteSize = MemoryLayout<T>.size
    assert(index + byteSize-1 < count, "Data not big enough to extract value")
    let slice = subdata(in: index..<(index+byteSize))
    let converted = slice.withUnsafeBytes { ptr in
      return ptr.bindMemory(to: T.self).first
    }
    index += byteSize
    return converted!
  }
  
  /// Gets an IP address in dotted format as a string
  func iPv4AddressAt(index: inout Int, defaultHost: String) -> String {
    assert(index + 4 <= count)
    let val1 = self[index]
    let val2 = self[index+1]
    let val3 = self[index+2]
    let val4 = self[index+3]
    index += 4
    
    if val1 == 0 && val2 == 0 && val3 == 0 && val4 == 0 {
      return defaultHost
    } else {
      return "\(val4).\(val3).\(val2).\(val1)"
    }
  }
  
  mutating func append<T>(_ value: T) {
    withUnsafePointer(to: value) {
      self.append(UnsafeRawPointer($0).assumingMemoryBound(to: UInt8.self),
                  count: MemoryLayout<T>.size)
    }
  }
  
  /// Strings are UTF8, with either 1 or 2 byte length header
  mutating func appendJamulusString(_ value: String, lengthSize: Int = 2) {
    guard let stringBytes = value.data(using: .utf8) else {
      return
    }
    
    if lengthSize == 1 {
      append(UInt8(stringBytes.count))
    } else {
      append(UInt16(stringBytes.count))
    }
    append(contentsOf: stringBytes)
  }
}
