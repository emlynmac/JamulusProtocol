
import Foundation

public struct ChannelInfo: Equatable, Sendable {
  public init(channelId: UInt8,
              countryId: UInt16,
              instrument: Instrument,
              skillLevel: UInt8,
              name: String,
              city: String,
              muted: Bool = false,
              volume: UInt8 = 0,
              gain: UInt16 = UInt16(Int16.max/2),
              pan: UInt16 = ChannelPan.center) {
    self.channelId = channelId
    self.countryId = countryId
    self.instrument = instrument
    self.skillLevel = skillLevel
    self.name = name
    self.city = city
    self.muted = muted
    self.volume = volume
    self.gain = gain
    self.pan = pan
  }
  
  public var channelId: UInt8
  public var countryId: UInt16
  public var instrument: Instrument
  public var skillLevel: UInt8
  public var name: String
  public var city: String
  
  public var muted: Bool = false
  public var volume: UInt8 = 0
  public var gain: UInt16 = UInt16(Int16.max/2)
  public var pan: UInt16 = ChannelPan.center
  
  static func parseFromData(data: Data, pos: inout Int, channelId: UInt8?) -> ChannelInfo {
    let kMinInfoSize = 9
    assert(data.count > kMinInfoSize)
    
    let channelId = channelId ?? data[pos]; pos += 1
    
    let countryId: UInt16 = data.numericalValueAt(index: &pos)
    let instrument: UInt32 = data.numericalValueAt(index: &pos)
    let skillLevel = data[pos]; pos += 1
    // Skip 4 bytes for unused IP address field
    pos += 4 // let ipAddr = data.iPv4AddressAt(index: &pos, defaultHost: "")
    let name = data.jamulusStringAt(index: &pos)
    let city = data.jamulusStringAt(index: &pos)
    return ChannelInfo(channelId: channelId,
                       countryId: countryId,
                       instrument: Instrument(rawValue: instrument) ?? .none,
                       skillLevel: skillLevel,
                       name: name,
                       city: city)
  }
}

extension Data {
  mutating func append(_ value: ChannelInfo) {
    // Don't send the clientId to the server
    append(value.countryId)
    append(value.instrument.rawValue)
    append(value.skillLevel)
    appendJamulusString(value.name)
    appendJamulusString(value.city)
  }
}
