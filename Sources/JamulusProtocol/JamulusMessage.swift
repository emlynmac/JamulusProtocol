
import Foundation

///
/// Jamulus Protocol messages
///
public enum JamulusMessage: Equatable {
  public static var timestamp: UInt32 {
    UInt32(UInt64(Date().timeIntervalSince1970 * 1000) & 0xffff)
  }
  
  // MARK: - Message Types
  case ack(ackType: UInt16, sequenceNumber: UInt8)
  case jitterBufSize(size: UInt16)
  case requestJitterBufSize
  case channelGain(channel: UInt8, gain: UInt16)
  case requestClientList
  case chatText(String)
  case audioTransportProperties(details: AudioTransportDetails)
  case requestAudioTransportProperties
  case requestChannelsInfo
  case clientList(channelInfo: [ChannelInfo])
  case setChannelInfo(ChannelInfo)
  case licenseRequired
  case versionAndOsOld(version: String, os: OsType)
  case channelPan(channel: UInt8, pan: UInt16)
  case muteStateChange(channel: UInt8, muted: Bool)
  case clientId(id: UInt8)
  case recorderState(state: RecorderState)
  case requestSplitMessagesSupport
  case splitMessagesSupport
  
  case ping(timeStamp: UInt32 = JamulusMessage.timestamp)
  case pingPlusClientCount(clientCount: UInt = 0,
                           timeStamp: UInt32 = JamulusMessage.timestamp)
  case serverFull
  case registerServer
  case unregisterServer
  case serverListWithDetails(details: [ServerDetail])
  case requestServerList
  case sendEmptyMessage
  case emptyMessage
  case disconnect
  case versionAndOs(version: String, os: OsType)
  case requestVersionAndOs
  case clientListNoAck(channelInfo: [ChannelInfo])
  case requestClientListAndDetails
  case channelLevelList([UInt8])
  case registerServerResponse
  case registerServerWithDetails
  case serverList(details: [ServerDetail])
  
  case splitMessageContainer
  
  
  // MARK: - Vars
  
  /// Jamulus Message IDs
  var messageId: UInt16 {
    switch self {
      
    case .ack: return 1
    case .jitterBufSize: return 10
    case .requestJitterBufSize: return 11
    case .channelGain: return 13
    case .requestClientList: return 16
    case .chatText: return 18
    case .audioTransportProperties: return 20
    case .requestAudioTransportProperties: return 21
    case .requestChannelsInfo: return 23
    case .clientList: return 24
    case .setChannelInfo: return 25
    case .licenseRequired: return 27
    case .versionAndOsOld: return 29
    case .channelPan: return 30
    case .muteStateChange: return 31
    case .clientId: return 32
    case .recorderState: return 33
    case .requestSplitMessagesSupport: return 34
    case .splitMessagesSupport: return 35
      
    case .ping: return 1001
    case .pingPlusClientCount: return 1002
    case .serverFull: return 1003
    case .registerServer: return 1004
    case .unregisterServer: return 1005
    case .serverListWithDetails: return 1006
    case .requestServerList: return 1007
    case .sendEmptyMessage: return 1008
    case .emptyMessage: return 1009
    case .disconnect: return 1010
    case .versionAndOs: return 1011
    case .requestVersionAndOs: return 1012
    case .clientListNoAck: return 1013
    case .requestClientListAndDetails: return 1014
    case .channelLevelList: return 1015
    case .registerServerResponse: return 1016
    case .registerServerWithDetails: return 1017
    case .serverList: return 1018
      
      // Other
    case .splitMessageContainer: return 2001
    }
  }
  
  /// Obtain the sequence number for the packet, if non-sequential
  var sequenceNumberOverride: UInt8? {
    switch self {
    case let .ack(_, sequenceNumber): return sequenceNumber
    default: return nil
    }
  }
  
  /// Does the protocol require an acknowledgement?
  var needsAck: Bool {
    guard messageId != 1 else { return false }  // Don't ack acks...
    
    return messageId < ApiConsts.messageIdNoAckStart &&
    messageId > ApiConsts.messageIdAckStart
  }
  
  // MARK: - Network functionality
  /// Convert packet from network into a message
  static func deserialize(from data: Data, defaultHost: String) -> JamulusMessage? {
    guard data.count >= ApiConsts.packetHeaderSizeWithoutChecksum else {
      assertionFailure("Garbage message data")
      return nil
    }
    var index = 2
    let messageType: UInt16 = data.numericalValueAt(index: &index)
    let sequence = data[4]
    let payload = data.subdata(in: ApiConsts.packetDataStartOffset..<data.count)
    
    var payloadIndex = 0
    
    switch messageType {
      
      // Client -> Server
    case 13: return createChannelGain(payload: payload)
    case 16: return .requestClientList
    case 23: return .requestChannelsInfo
    case 25: return createSetChannelInfo(payload: payload)
    case 30: return createChannelPan(payload: payload)
    case 31: return createMuteChange(payload: payload)
    case 1007: return .requestServerList
    case 1012: return .requestVersionAndOs
    case 1014: return .requestClientListAndDetails
      
      // Server -> Client
    case 24: return createClientList(payload: payload)
    case 33: return createRecorderState(payload: payload)
    case 29: return createVersionAndOsOld(payload: payload)
    case 27: return .licenseRequired
    case 32: return .clientId(id: payload[payloadIndex])
    case 1003: return .serverFull
    case 1006: return createServerListWithDetails(payload: payload,
                                                   defaultHost: defaultHost)
    case 1011: return createVersionAndOs(payload: payload)
      
    case 1018: return createServerList(payload: payload,
                                       defaultHost: defaultHost)
    case 1013: return createClientListNoAck(payload: payload)
    case 1015: return createChannelLevelList(payload: payload)
      
      // Both
    case 1: return .ack(ackType: messageType, sequenceNumber: UInt8(sequence))
    case 10: return .jitterBufSize(size: payload.numericalValueAt(index: &payloadIndex))
    case 11: return .requestJitterBufSize
    case 18: return createChatText(payload: payload)
    case 20: return .audioTransportProperties(
      details: AudioTransportDetails.parseFrom(data: payload)
    )
    case 21: return .requestAudioTransportProperties
    case 34: return .requestSplitMessagesSupport
    case 35: return .splitMessagesSupport
      
    case 1001: return createPing(data: data, payload: payload)
    case 1002: return createPingWithClientCount(data: data, payload: payload)
    case 1010: return .disconnect
    case 2001: return .splitMessageContainer
      
      // Server -> Server
    case 1004: return .registerServer
    case 1005: return .unregisterServer
    case 1008: return .sendEmptyMessage
    case 1009: return .emptyMessage
    case 1016: return .registerServerResponse
    case 1017: return .registerServerWithDetails
      
    default:
      print("Unhandled Message Type (\(messageType))!")
      return nil
    }
  }
  
  /// Builds the message payload
  var payload: Data {
    var payload = Data()
    
    switch self {
      // Client -> Server
    case .channelGain(let channel, let gain):
      payload.append(channel)
      payload.append(gain)
      
    case .setChannelInfo(let channelInfo): payload.append(channelInfo)
      
    case .channelPan(let channel, let pan):
      payload.append(channel)
      payload.append(pan)
      
    case .muteStateChange(let channel, let muted):
      payload.append(channel)
      payload.append(muted ? 1 : 0)
      
      // Both
    case .ack(let ackType, _): payload.append(ackType)
    case .ping(let timeStamp): payload.append(timeStamp)
    case .jitterBufSize(let size): payload.append(size)
    case .chatText(let text):
      let bytes = text.data(using: .utf8) ?? Data()
      payload.append(UInt16(bytes.count))
      payload.append(bytes)
      
    case .audioTransportProperties(let details): payload.append(details)
      
      // Server -> Client
    case .clientId(let id): payload.append(id)
    case .pingPlusClientCount(let clientCount, let timeStamp):
      payload.append(timeStamp)
      payload.append(UInt8(clientCount))
      
    default: break
    }
    
    return payload
  }
  
  // MARK: - Utility Functions
  static func crcFunc(for data: Data) -> UInt16 {
    let polyNomial: UInt32 = 0x00001020
    var result: UInt32 = ~0
    for byte in data {
      for i in 0..<8 {
        result <<= 1
        if (result & 0x10000) > 0 { result |= 1 }
        if (byte & (1 << (7 - i) )) > 0 { result ^= 1 }
        if (result & 1) > 0 { result ^= polyNomial }
      }
    }
    result = ~result
    return UInt16(result & 0xFFFF)
  }
}
