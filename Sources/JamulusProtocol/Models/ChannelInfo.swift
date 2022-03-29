
import Foundation

public struct ChannelInfo: Equatable {
  var clientId: UInt8
  var countryId: UInt16
  var instrument: Instrument
  var skillLevel: UInt8
  var name: String
  var city: String
  
  var muted: Bool = false
  var volume: UInt8 = 0
  var gain: UInt16 = 0
  var pan: UInt16 = ChannelPan.center
  
  static func parseFromData(data: Data, pos: inout Int, clientId: UInt8?) -> ChannelInfo {
    let kMinInfoSize = 9
    assert(data.count > kMinInfoSize)
    
    let clientId = clientId ?? data[pos]; pos += 1
    
    let countryId: UInt16 = data.numericalValueAt(index: &pos)
    let instrument: UInt32 = data.numericalValueAt(index: &pos)
    let skillLevel = data[pos]; pos += 1
    let name = data.jamulusStringAt(index: &pos)
    let city = data.jamulusStringAt(index: &pos)
    return ChannelInfo(clientId: clientId,
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
    append(value.name)
    append(value.city)
  }
}
