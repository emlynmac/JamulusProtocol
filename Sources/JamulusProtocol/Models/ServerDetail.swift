
import Foundation

public struct ServerDetail: CustomStringConvertible, Equatable, Identifiable,
                              Sendable {
  
  public init(name: String,
              ipAddress: String,
              port: UInt16,
              maxClients: Int? = nil,
              perm: Bool = false,
              city: String? = nil,
              country: String? = nil,
              serverInternalName: String? = nil,
              pingTimeMs: Int? = nil,
              connectedClients: Int? = nil) {
    self.name = name
    self.ipAddress = ipAddress
    self.port = port
    self.maxClients = maxClients
    self.perm = perm
    self.city = city
    self.country = country
    self.serverInternalName = serverInternalName
    self.pingTimeMs = pingTimeMs
    self.connectedClients = connectedClients
  }
  
  
  // From ServerDetails message
  public var id: String { "\(ipAddress):\(port)" }
  public var name: String
  public var ipAddress: String {
    didSet {
      
    }
  }
  public var port: UInt16
  public var maxClients: Int?
  public var perm: Bool = false
  public var city: String?
  public var country: String?
  public var serverInternalName: String?
  
  
  // From ping message
  public var pingTimeMs: Int?
  public var connectedClients: Int?
  
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
