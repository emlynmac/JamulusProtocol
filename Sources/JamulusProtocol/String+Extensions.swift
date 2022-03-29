
import Foundation

extension String {
  public var asJamulusUrl: URL? {
    var components = URLComponents()
    let vals = self.components(separatedBy: ":")
    
    guard vals.count > 0, !vals[0].isEmpty else {
      return nil
    }

    components.host = vals[0]
    
    if vals.count > 1,
       let port = UInt(vals[1]) {
      components.port = Int(port)
    } else {
      components.port = Int(ApiConsts.defaultPort)
    }
    return components.url
  }
}
