
import Foundation


func parsePingFrom(data: Data, payload: Data) -> JamulusMessage {
  var index = 0
  if payload.count == 4 {
    let timeStamp: UInt32 = payload.numericalValueAt(index: &index)
    return .ping(timeStamp: timeStamp)
  }
  return .ping()
}

func parsePingAndClientCountFrom(data: Data,
                               payload: Data) -> JamulusMessage {
  var index = 0
  if payload.count == 5 {
    let timeStamp: UInt32 = payload.numericalValueAt(index: &index)
    return .pingPlusClientCount(clientCount: UInt(payload[index]),
                                timeStamp: timeStamp)
  }
  return .pingPlusClientCount(clientCount: 0)
}

func parseChannelLevelsFrom(payload: Data) -> JamulusMessage {
  // Levels are 4 bits each, sent as a pair
  var vals: [UInt8] = []
  for byte in payload {
    let first = byte & 0xF
    let second = (byte & 0xF0) >> 4
    vals.append(first)
    if second != 0xF { vals.append(second) }
  }
  return .channelLevelList(vals)
}

func parseClientListFrom(payload: Data) -> JamulusMessage {
  return .clientList(channelInfo: parseChannelInfos(payload: payload))
}

func parseClientListNoAckFrom(payload: Data) -> JamulusMessage {
  return .clientListNoAck(channelInfo: parseChannelInfos(payload: payload))
}

private func parseChannelInfos(payload: Data) -> [ChannelInfo] {
  var pos = 0
  var channels: [ChannelInfo] = []
  let kMinClientListSize = 12
  
  while ( (payload.count - pos) >= kMinClientListSize) {
    let channelInfo = ChannelInfo.parseFromData(data: payload,
                                                pos: &pos,
                                                channelId: nil)
    channels.append(channelInfo)
  }
  return channels
}

func parseServerListWithDetailsFrom(payload: Data,
                                 defaultHost: String) -> JamulusMessage {
  let kMinServerListSize = 6
  
  var pos = 0
  var details: [ServerDetail] = []
  
  while ( (payload.count - pos) >= kMinServerListSize) {
    let detail = ServerDetail.parseFromData(data: payload,
                                            pos: &pos,
                                            defaultHost: defaultHost)
    details.append(detail)
  }
  return .serverListWithDetails(details: details)
}

func parseServerListFrom(payload: Data,
                      defaultHost: String) -> JamulusMessage {
  let kMinServerListSize = 5
  var pos = 0
  var details: [ServerDetail] = []
  
  while ( (payload.count - pos) >= kMinServerListSize) {
    let serverDetail = ServerDetail.parseReducedFromData(data: payload,
                                                         pos: &pos,
                                                         defaultHost: defaultHost)
    details.append(serverDetail)
  }
  return .serverList(details: details)
}

func parseDetailedServerListFrom(payload: Data,
                              defaultHost: String) -> JamulusMessage {
  let kMinServerListSize = 16
  var details: [ServerDetail] = []
  var pos = 0
  
  while ( (payload.count - pos) >= kMinServerListSize) {
    let serverDetail = ServerDetail.parseFromData(data: payload,
                                                  pos: &pos,
                                                  defaultHost: defaultHost)
    details.append(serverDetail)
  }
  return .serverListWithDetails(details: details)
}

func parseChatTextFrom(payload: Data) -> JamulusMessage {
  var text = String()
  var index = 0
  if payload.count > 2 {
    text = payload.jamulusStringAt(index: &index)
  }
  return .chatText(text)
}

func parseChannelPanFrom(payload: Data) -> JamulusMessage {
  assert(payload.count == 3)
  var index = 1
  var pan: UInt16 = ChannelPan.center
  pan = payload.numericalValueAt(index: &index)
  return .channelPan(channel: payload[0], pan: pan)
}

func parseChannelGainFrom(payload: Data) -> JamulusMessage {
  assert(payload.count == 3)
  var index = 1
  var gain: UInt16 = 0
  gain = payload.numericalValueAt(index: &index)
  return .channelGain(channel: payload[0], gain: gain)
}

func parseMuteChangeFrom(payload: Data) -> JamulusMessage {
  assert(payload.count == 2)
  return .muteStateChange(channel: payload[0], muted: payload[1] > 0)
}

func parseChannelInfoFrom(payload: Data) -> JamulusMessage {
  var pos = 0
  return .sendChannelInfo(ChannelInfo.parseFromData(data: payload,
                                                   pos: &pos,
                                                   channelId: 0))
}

func parseVersionAndOs(payload: Data) -> (version: String, os: OsType) {
  var pos = 0
  let osRaw = payload[0]; pos += 1
  let version = payload.jamulusStringAt(index: &pos)
  let os = OsType(rawValue: osRaw) ?? .linux  // Default
  return (version, os)
}

func parseVersionAndOsAckedFrom(payload: Data) -> JamulusMessage {
  let (version, os) = parseVersionAndOs(payload: payload)
  return .versionAndOsOld(version: version, os: os)
}

func parseVersionAndOsFrom(payload: Data) -> JamulusMessage {
  let (version, os) = parseVersionAndOs(payload: payload)
  return .versionAndOs(version: version, os: os)
}

func parseRecorderStateFrom(payload: Data) -> JamulusMessage {
  var state = RecorderState.unknown
  if let byte = payload.first,
     let val = RecorderState(rawValue: byte) {
    state = val
  }
  return .recorderState(state: state)
}

func parseSplitMessage(payload: Data) -> JamulusMessage {
  var pos = 0
  let id: UInt16 = payload.numericalValueAt(index: &pos)
  let totalParts: UInt8 = payload[pos]; pos += 1
  let part: UInt8 = payload[pos]; pos += 1
 
  return .splitMessageContainer(id: id,
                                totalParts: totalParts, part: part,
                                payload: payload[pos...])
}
