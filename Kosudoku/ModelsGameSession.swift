//
//  GameSession.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation
import SwiftData

enum GameStatus: String, Codable {
    case waiting      // Waiting for players to join
    case active       // Game is in progress
    case completed    // Game has ended
    case abandoned    // Game was abandoned
}

enum DifficultyLevel: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
    case expert
}

@Model
final class GameSession {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var status: GameStatus
    var difficulty: DifficultyLevel
    
    // Sudoku puzzle data
    var puzzleData: String // JSON string of the initial puzzle
    var solutionData: String // JSON string of the solution
    
    // CloudKit record name for syncing
    var cloudKitRecordName: String?
    
    // Host information
    var hostRecordName: String
    
    // Invited players (CloudKit record names)
    var invitedPlayers: [String] = []
    
    // Players who declined the invitation
    var declinedPlayers: [String] = []
    
    init(hostRecordName: String, difficulty: DifficultyLevel, puzzleData: String, solutionData: String, invitedPlayers: [String] = []) {
        self.id = UUID()
        self.createdAt = Date()
        self.status = .waiting
        self.difficulty = difficulty
        self.hostRecordName = hostRecordName
        self.puzzleData = puzzleData
        self.solutionData = solutionData
        self.invitedPlayers = invitedPlayers
    }
}
