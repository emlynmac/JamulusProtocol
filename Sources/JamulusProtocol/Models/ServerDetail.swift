
import Foundation

public struct ServerDetail: CustomStringConvertible, Equatable, Identifiable {
  
  // From ServerDetails message
  public var id: String { "\(ipAddress):\(port)" }
  var name: String
  var ipAddress: String {
    didSet {
      
    }
  }
  var port: UInt16
  var maxClients: Int?
  var perm: Bool = false
  var city: String?
  var country: String?
  var serverInternalName: String?
  
  
  // From ping message
  var pingTimeMs: Int?
  var connectedClients: Int?
  
  public var description: String {
    return "\(name), \(city ?? "-") (\(ipAddress):\(port)) | \(maxClients != nil ? "Conn. limit: \(maxClients!)" : "")"
  }
  
  
  static func parseFromData(data: Data, pos: inout Int,
                            defaultHost: String) -> ServerDetail {
    let ipAddr = data.iPv4AddressAt(index: &pos,
                                    defaultHost: defaultHost)
    let ipPort: UInt16 = data.numericalValueAt(index: &pos)
    let countryCode: UInt16 = data.numericalValueAt(index: &pos)
    let maxClients: UInt8 = data[pos]; pos += 1
    let perm: Bool = Bool(data[pos] == 1); pos += 1
    
    let name = data.jamulusStringAt(index: &pos)
    let internalName = data.jamulusStringAt(index: &pos)
    let city = data.jamulusStringAt(index: &pos)
    
    return ServerDetail(name: name,
                        ipAddress: ipAddr,
                        port:  ipPort == 0 ? ApiConsts.defaultPort: ipPort,
                        maxClients: Int(maxClients),
                        perm: perm,
                        city: city,
                        country: "\(countryCode)",
                        serverInternalName: internalName)
  }
  
  static func parseReducedFromData(data: Data, pos: inout Int,
                                   defaultHost: String) -> ServerDetail {
    let ipAddr = data.iPv4AddressAt(index: &pos,
                                    defaultHost: defaultHost)
    let ipPort: UInt16 = data.numericalValueAt(index: &pos)
    let name = data.jamulusStringAt(index: &pos, lengthSize: 1)
    
    return ServerDetail(name: name,
                        ipAddress: ipAddr,
                        port: ipPort == 0 ? ApiConsts.defaultPort: ipPort)
  }
}
