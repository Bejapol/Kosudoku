//
//  PlayerGameState.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation
import SwiftData

@Model
final class PlayerGameState {
    @Attribute(.unique) var id: UUID
    var playerRecordName: String
    var playerUsername: String
    var gameSessionID: UUID? // Changed from relationship to simple UUID property
    
    // Current board state for this player
    var currentBoardData: String // JSON string of filled cells
    
    // Scoring
    var score: Int
    var correctGuesses: Int
    var incorrectGuesses: Int
    var cellsCompleted: [String] // Array of cell positions completed by this player (e.g., ["0-0", "0-1"])
    
    // Timing
    var joinedAt: Date
    var lastMoveAt: Date?
    
    // Currently selected cell (synced to show highlights to other players)
    var selectedRow: Int?
    var selectedCol: Int?
    
    /// Custom color purchased from the store (nil = use auto-assigned)
    var customColorRawValue: Int?
    
    // CloudKit record name for updating the existing record
    var cloudKitRecordName: String?
    
    init(playerRecordName: String, playerUsername: String, gameSession: GameSession) {
        self.id = UUID()
        self.playerRecordName = playerRecordName
        self.playerUsername = playerUsername
        self.gameSessionID = gameSession.id
        self.currentBoardData = "{}"
        self.score = 0
        self.correctGuesses = 0
        self.incorrectGuesses = 0
        self.cellsCompleted = []
        self.joinedAt = Date()
    }
}
