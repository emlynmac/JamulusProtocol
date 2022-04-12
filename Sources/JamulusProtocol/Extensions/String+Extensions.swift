
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
  
  /// Attempts to parse a date from a jamulus chat message
  public var chatDate: Date? {
    if let found = dateFormatter.date(from: self) {
      let bits = Calendar.current
        .dateComponents([.hour, .minute,.second], from: found)
      
      return Calendar.current.date(
        bySettingHour: bits.hour!, minute: bits.minute!, second: bits.second!,
        of: Date(),
        matchingPolicy: .strict,repeatedTimePolicy: .first, direction: .forward
      )
    }
    return nil
  }
}

var dateFormatter: DateFormatter {
  let formatter = DateFormatter()
  formatter.dateFormat = "(hh:mm:ss a)"
  return formatter
}
