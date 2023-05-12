//
//  JamulusPacket.swift
//  
//
//  Created by Emlyn Bolton on 2023-05-12.
//

import Foundation

enum JamulusPacket: Equatable, Sendable {
  case ackMessage(ackType: UInt16, sequenceNumber: UInt8)
  case messageNeedingAck(JamulusMessage, UInt8)
  case messageNoAck(JamulusMessage)
  case audio(Data)
  case error(JamulusError)
}
