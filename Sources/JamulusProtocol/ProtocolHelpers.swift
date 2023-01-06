
import Foundation

/// CRC value for jamulus messaging packets
func jamulusCrc(for data: Data) -> UInt16 {
  let polynomial: UInt32 = 0x00001020
  var result: UInt32 = ~0
  for byte in data {
    for i in 0..<8 {
      result <<= 1
      if (result & 0x10000) > 0 { result |= 1 }
      if (byte & (1 << (7 - i) )) > 0 { result ^= 1 }
      if (result & 1) > 0 { result ^= polynomial }
    }
  }
  result = ~result
  return UInt16(result & 0xFFFF)
}

/// Simple sequence handler
func nextSequenceNumber(val: inout UInt8) -> UInt8 {
  let newVal = val &+ 1
  val = newVal
  return val
}

/// Serialize a jamulus message to send over the network
func messageToData(message: JamulusMessage, nextSeq: UInt8) -> Data {
  // Add zero word header
  var data = Data([0,0])
  // Add Type
  data.append(message.messageId)
  
  // Add sequence number
  if let override = message.sequenceNumberOverride {
    data.append(override)
  } else {
    data.append(nextSeq)
  }
  // Add payload data
  let payload = message.payload
  // Add data length
  data.append(UInt16(payload.count))
  // and data
  data.append(contentsOf: payload)
  
  // Add CRC bytes
  let crc = jamulusCrc(for: data)
  data.append(crc)
  return data
}

/// Parse network data into a jamulus packet
func parseData(data: Data, defaultHost: String) -> JamulusPacket {
  if data.count >= ApiConsts.packetHeaderSize, data[0] == 0, data[1] == 0 {
    var index = 5
    let dataLen: UInt16 = data.numericalValueAt(index: &index)
    
    // Check length
    if data.count == Int(dataLen) + ApiConsts.packetHeaderSize {
      let dataPacket = data.subdata(in: 0..<data.count-2)
      var crcOffset = dataPacket.count
      let crc: UInt16 = data.numericalValueAt(index: &crcOffset)
      // Check validity
      if crc == jamulusCrc(for: dataPacket),
         let message = JamulusMessage.deserialize(from: dataPacket,
                                                  defaultHost: defaultHost) {
        let sequence = data[4]
        
        switch message {
        case .ack(let ackType, let sequenceNumber):
          return .ackMessage(ackType: ackType, sequenceNumber: sequenceNumber)
          
        default:
          break
        }
        return message.needsAck ?
          .messageNeedingAck(message, sequence) :
          .messageNoAck(message)
      }
    }
  } else {
    // Data packet - just push that out to the audio handler
    return .audio(data)
  }
  return .error(JamulusError.invalidPacket(data))
}

///
/// Takes a partial message and stores for reassembly. If a complete message,
/// emits the data and removes the temporary storage
///
func handleSplitMessage(id: UInt16, total: Int, part: Int,
                        payload: Data,
                        storage: inout [UInt16: [Data?]]) -> Data? {
  if storage[id] != nil {
    assert(part < storage[id]!.count)
    storage[id]?[part] = payload
  } else {
    // No existing reconstruction, start building
    var completePacket = [Data?](repeating: nil, count: total)
    completePacket[part] = payload
    storage[id] = completePacket
  }
  
  if let parts = storage[id] {
    var message = Data()
    for part in parts {
      guard part != nil else { return nil }
      message.append(part)
    }
    storage.removeValue(forKey: id)
    return message
  }
  
  return nil
}
