
import Foundation

///
/// Jamulus Protocol messages
///
public enum JamulusMessage: Equatable {
  // MARK: - Connection Setup and Teardown
  /// Tell the client their channel ID on connection
  case clientId(id: UInt8)
  
  /// Send channel info - used to intially send client details to the server
  case sendChannelInfo(ChannelInfo)
  
  /// Request the client list from the server
  case requestClientList
  
  /// Request the audio transport properties for the remote host
  case requestAudioTransportProperties
  /// Send details of the audio transport to the remote host
  case audioTransportProperties(details: AudioTransportDetails)
  
  /// Request that the server send the list of mixer channels
  case requestChannelsInfo
  
  /// Request the remote jitter buffer size
  case requestJitterBufSize
  /// Set the remote jitter buffer size
  case jitterBufSize(size: UInt16)
  
  /// Response if attempting to connect to a server with no more channels available
  case serverFull
  
  /// Unused at this time
  case licenseRequired
  
  /// Request the remote host to send details of its OS and protocol version
  case requestVersionAndOs
  
  /// Provide details of the host to the remote
  case versionAndOsOld(version: String, os: OsType)
  /// Provide details of the host to the remote, without requiring acknowledgement
  case versionAndOs(version: String, os: OsType)
  
  /// Disconnect from the remote host
  /// A host should continue to send this message until the audio stream has ceased
  /// from the remote endpoint.
  case disconnect
  
  // MARK: - Client Interactions
  /// The absolute list of channels in the mixer. Will be called when
  /// clients join / leave the jam
  case clientList(channelInfo: [ChannelInfo])
  
  /// Provides the VU meter levels to the client from the server
  case channelLevelList([UInt8])
  
  /// Set the gain for the channel to a value between 0 and Int16.max
  case channelGain(channel: UInt8, gain: UInt16)
  
  /// Set the pan for the channel between 0 (L) and Int16.max (R)
  case channelPan(channel: UInt8, pan: UInt16)
  
  /// Set the mute state of the channel
  case muteStateChange(channel: UInt8, muted: Bool)
  
  /// Encapsulates a chat message
  case chatText(String)
  
  /// Tell a client the state of the server mix recorder
  case recorderState(state: RecorderState)
  
  
  // MARK: - Directory Server Listing Messages
  case registerServer
  case unregisterServer
  case serverListWithDetails(details: [ServerDetail])
  case requestServerList
  case sendEmptyMessage
  case emptyMessage
  case requestClientListAndDetails
  case clientListNoAck(channelInfo: [ChannelInfo])
  case registerServerResponse
  case registerServerWithDetails
  case serverList(details: [ServerDetail])
  
  
  // MARK: - Protocol State Messages
  /// Ask if a host supports split messages
  case requestSplitMessagesSupport
  /// Tell the remote that split messages are supported
  case splitMessagesSupport
  /// Container for split messages
  case splitMessageContainer(id: UInt16,
                             totalParts: UInt8, part: UInt8,
                             payload: Data)
  
  /// Acknowldegement message, for a message type and sequence number
  case ack(ackType: UInt16, sequenceNumber: UInt8)
  
  /// Ping the server - used for determining connection state and
  /// can be used to determine jitter buffers to a degree
  case ping(timeStamp: UInt32)
  
  /// Ping a server and get the number of connected clients
  /// Used primarily for evaluation a server prior to connecting
  case pingPlusClientCount(clientCount: UInt = 0,
                           timeStamp: UInt32)
  
  /// Jamulus Protocol Message ID
  public var messageId: UInt16 {
    switch self {
      
      // Messages requiring acks
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
    case .sendChannelInfo: return 25
    case .licenseRequired: return 27
    case .versionAndOsOld: return 29
    case .channelPan: return 30
    case .muteStateChange: return 31
    case .clientId: return 32
    case .recorderState: return 33
    case .requestSplitMessagesSupport: return 34
    case .splitMessagesSupport: return 35
      
      // Not requiring acks
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
}

// MARK: - Network helper functions
extension JamulusMessage {
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
    case 13: return parseChannelGainFrom(payload: payload)
    case 16: return .requestClientList
    case 23: return .requestChannelsInfo
    case 25: return parseChannelInfoFrom(payload: payload)
    case 30: return parseChannelPanFrom(payload: payload)
    case 31: return parseMuteChangeFrom(payload: payload)
    case 1007: return .requestServerList
    case 1012: return .requestVersionAndOs
    case 1014: return .requestClientListAndDetails
      
      // Server -> Client
    case 24: return parseClientListFrom(payload: payload)
    case 33: return parseRecorderStateFrom(payload: payload)
    case 29: return parseVersionAndOsAckedFrom(payload: payload)
    case 27: return .licenseRequired
    case 32: return .clientId(id: payload[payloadIndex])
    case 1003: return .serverFull
    case 1006: return parseServerListWithDetailsFrom(payload: payload,
                                                  defaultHost: defaultHost)
    case 1011: return parseVersionAndOsFrom(payload: payload)
      
    case 1018: return parseServerListFrom(payload: payload,
                                       defaultHost: defaultHost)
    case 1013: return parseClientListNoAckFrom(payload: payload)
    case 1015: return parseChannelLevelsFrom(payload: payload)
      
      // Both
    case 1: return .ack(ackType: payload.numericalValueAt(index: &payloadIndex),
                        sequenceNumber: UInt8(sequence))
    case 10: return .jitterBufSize(size: payload.numericalValueAt(index: &payloadIndex))
    case 11: return .requestJitterBufSize
    case 18: return parseChatTextFrom(payload: payload)
    case 20: return .audioTransportProperties(
      details: AudioTransportDetails.parseFrom(data: payload)
    )
    case 21: return .requestAudioTransportProperties
    case 34: return .requestSplitMessagesSupport
    case 35: return .splitMessagesSupport
      
    case 1001: return parsePingFrom(data: data, payload: payload)
    case 1002: return parsePingAndClientCountFrom(data: data, payload: payload)
    case 1010: return .disconnect
    case 2001: return parseSplitMessage(payload: payload)
      
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
  
  ///
  /// Data payload for sending over the network
  ///
  var payload: Data {
    var payload = Data()
    
    switch self {
      // Client -> Server
    case .channelGain(let channel, let gain):
      payload.append(channel)
      payload.append(gain)
      
    case .sendChannelInfo(let channelInfo): payload.append(channelInfo)
      
    case .channelPan(let channel, let pan):
      payload.append(channel)
      payload.append(pan)
      
    case .muteStateChange(let channel, let muted):
      payload.append(channel)
      payload.append(muted ? UInt8(1) : UInt8(0))
      
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
      
    default:
      // No message payload
      break
    }
    
    return payload
  }
}
