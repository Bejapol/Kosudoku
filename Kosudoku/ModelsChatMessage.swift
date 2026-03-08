//
//  ChatMessage.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation
import SwiftData

enum ChatMessageType: String, Codable {
    case text
    case system  // System messages like "Player joined", "Game started"
    case reaction
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var senderRecordName: String
    var senderUsername: String
    var content: String
    var messageType: ChatMessageType
    var timestamp: Date
    var gameSessionID: UUID? // Changed from relationship to simple UUID property
    
    // For group chats outside of games
    var groupChatID: String?
    
    init(senderRecordName: String, senderUsername: String, content: String, messageType: ChatMessageType = .text, gameSession: GameSession? = nil, groupChatID: String? = nil) {
        self.id = UUID()
        self.senderRecordName = senderRecordName
        self.senderUsername = senderUsername
        self.content = content
        self.messageType = messageType
        self.timestamp = Date()
        self.gameSessionID = gameSession?.id
        self.groupChatID = groupChatID
    }
}
