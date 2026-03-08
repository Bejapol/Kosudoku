//
//  GameManager.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation
import SwiftData
import SwiftUI
import CloudKit

/// Manages the current game state and coordinates between local and CloudKit
@Observable
class GameManager {
    var currentGame: GameSession?
    var currentPlayerState: PlayerGameState?
    var currentBoard: SudokuBoard?
    var solutionBoard: SudokuBoard?
    var otherPlayers: [PlayerGameState] = []
    
    var selectedCell: (row: Int, col: Int)?
    var isGameActive = false
    var gameStartTime: Date?
    
    private let cloudKit = CloudKitService.shared
    private let modelContext: ModelContext
    
    // Timer for periodic sync
    private var syncTimer: Timer?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Game Creation
    
    /// Create a new game session
    func createGame(difficulty: DifficultyLevel, invitedPlayers: [String] = []) async throws {
        guard let hostRecordName = cloudKit.currentUserRecordName else {
            throw GameError.notAuthenticated
        }
        
        // Generate puzzle
        let (puzzle, solution) = SudokuGenerator.generatePuzzle(difficulty: difficulty)
        
        // Create game session
        let session = GameSession(
            hostRecordName: hostRecordName,
            difficulty: difficulty,
            puzzleData: puzzle.toJSONString(),
            solutionData: solution.toJSONString()
        )
        
        // Save to CloudKit
        try await cloudKit.createGameSession(session)
        
        // Save locally
        modelContext.insert(session)
        try modelContext.save()
        
        // Join the game as host
        try await joinGame(session)
        
        currentGame = session
        currentBoard = puzzle
        solutionBoard = solution
    }
    
    // MARK: - Game Join/Leave
    
    /// Join an existing game
    func joinGame(_ session: GameSession) async throws {
        guard let playerRecordName = cloudKit.currentUserRecordName,
              let username = cloudKit.currentUserProfile?.username else {
            throw GameError.notAuthenticated
        }
        
        // Create player state
        let playerState = PlayerGameState(
            playerRecordName: playerRecordName,
            playerUsername: username,
            gameSession: session
        )
        
        // Save to CloudKit
        if let gameRecordName = session.cloudKitRecordName {
            try await cloudKit.savePlayerState(playerState, gameRecordName: gameRecordName)
            
            // Subscribe to game updates (non-critical, will fall back to polling if it fails)
            try? await cloudKit.subscribeToGameUpdates(gameRecordName: gameRecordName)
        }
        
        // Save locally
        modelContext.insert(playerState)
        try modelContext.save()
        
        currentPlayerState = playerState
        currentGame = session
        
        // Load board
        if let board = SudokuBoard.fromJSONString(session.puzzleData) {
            currentBoard = board
        }
        if let solution = SudokuBoard.fromJSONString(session.solutionData) {
            solutionBoard = solution
        }
    }
    
    /// Start the game
    func startGame() async throws {
        guard let game = currentGame else {
            throw GameError.noActiveGame
        }
        
        game.status = .active
        game.startedAt = Date()
        gameStartTime = Date()
        isGameActive = true
        
        // Update in CloudKit
        try await cloudKit.updateGameSession(game)
        
        // Save locally
        try modelContext.save()
        
        // Start sync timer
        startSyncTimer()
        
        // Send system message
        if let gameRecordName = game.cloudKitRecordName,
           let playerRecordName = cloudKit.currentUserRecordName,
           let username = cloudKit.currentUserProfile?.username {
            let message = ChatMessage(
                senderRecordName: playerRecordName,
                senderUsername: username,
                content: "Game started!",
                messageType: .system,
                gameSession: game
            )
            try await cloudKit.sendChatMessage(message, gameRecordName: gameRecordName)
        }
    }
    
    // MARK: - Game Actions
    
    /// Make a move on the board
    func makeMove(row: Int, col: Int, value: Int) async throws {
        guard let game = currentGame,
              let playerState = currentPlayerState,
              var board = currentBoard,
              let solution = solutionBoard else {
            throw GameError.noActiveGame
        }
        
        // Check if cell is fixed
        if board[row, col].isFixed {
            throw GameError.cannotModifyFixedCell
        }
        
        // Check if cell already completed by another player
        if let completedBy = board[row, col].completedBy,
           completedBy != playerState.playerRecordName {
            throw GameError.cellAlreadyCompleted
        }
        
        // Validate the move
        let isCorrect = SudokuGenerator.validateMove(board, solution: solution, row: row, col: col, value: value)
        
        if isCorrect {
            // Update board
            board[row, col].value = value
            board[row, col].completedBy = playerState.playerRecordName
            currentBoard = board
            
            // Update player state
            playerState.currentBoardData = board.toJSONString()
            playerState.correctGuesses += 1
            playerState.cellsCompleted.append("\(row)-\(col)")
            
            // Calculate points
            let points = ScoringSystem.pointsForCorrectGuess(difficulty: game.difficulty)
            playerState.score += points
            playerState.lastMoveAt = Date()
            
            // Update puzzle data in game session
            game.puzzleData = board.toJSONString()
            
        } else {
            // Incorrect guess
            playerState.incorrectGuesses += 1
            playerState.score += ScoringSystem.pointsForIncorrectGuess()
            playerState.lastMoveAt = Date()
        }
        
        // Save locally
        try modelContext.save()
        
        // Sync to CloudKit
        if let gameRecordName = game.cloudKitRecordName {
            try await cloudKit.savePlayerState(playerState, gameRecordName: gameRecordName)
            try await cloudKit.updateGameSession(game)
        }
        
        // Check if board is complete
        if SudokuGenerator.isBoardComplete(board) {
            try await completeGame()
        }
    }
    
    /// Add or remove a note (pencil mark) from a cell
    func toggleNote(row: Int, col: Int, note: Int) {
        guard var board = currentBoard else { return }
        
        if board[row, col].notes.contains(note) {
            board[row, col].notes.remove(note)
        } else {
            board[row, col].notes.insert(note)
        }
        
        currentBoard = board
        
        // Save locally
        if let playerState = currentPlayerState {
            playerState.currentBoardData = board.toJSONString()
            try? modelContext.save()
        }
    }
    
    /// Give a hint by filling in a random empty cell (no points awarded)
    func giveHint() {
        guard var board = currentBoard,
              let solution = solutionBoard,
              let playerState = currentPlayerState else {
            return
        }
        
        // Find all empty cells that aren't fixed
        var emptyCells: [(row: Int, col: Int)] = []
        for row in 0..<9 {
            for col in 0..<9 {
                if !board[row, col].isFixed && board[row, col].value == nil {
                    emptyCells.append((row, col))
                }
            }
        }
        
        // If there are no empty cells, do nothing
        guard !emptyCells.isEmpty else {
            return
        }
        
        // Pick a random empty cell
        let randomCell = emptyCells.randomElement()!
        let row = randomCell.row
        let col = randomCell.col
        
        // Fill it with the correct answer from the solution
        if let correctValue = solution[row, col].value {
            board[row, col].value = correctValue
            board[row, col].completedBy = playerState.playerRecordName
            
            // Update current board
            currentBoard = board
            
            // Update player state (no points, no guess count)
            playerState.currentBoardData = board.toJSONString()
            playerState.lastMoveAt = Date()
            
            // Save locally
            try? modelContext.save()
        }
    }
    
    /// Complete the game
    private func completeGame() async throws {
        guard let game = currentGame,
              let playerState = currentPlayerState else {
            throw GameError.noActiveGame
        }
        
        game.status = .completed
        game.completedAt = Date()
        isGameActive = false
        
        // Calculate final score
        if let startTime = gameStartTime {
            let timeElapsed = Date().timeIntervalSince(startTime)
            let finalScore = ScoringSystem.calculateFinalScore(
                correctGuesses: playerState.correctGuesses,
                incorrectGuesses: playerState.incorrectGuesses,
                cellsCompleted: playerState.cellsCompleted.count,
                difficulty: game.difficulty,
                timeElapsed: timeElapsed,
                finishPosition: 1 // TODO: Determine actual position
            )
            playerState.score = finalScore
            
            // Update user profile
            if let profile = cloudKit.currentUserProfile {
                profile.totalScore += finalScore
                profile.gamesPlayed += 1
                profile.gamesWon += 1
                try await cloudKit.saveUserProfile(profile)
            }
        }
        
        // Save locally
        try modelContext.save()
        
        // Update CloudKit
        try await cloudKit.updateGameSession(game)
        
        // Stop sync timer
        stopSyncTimer()
    }
    
    // MARK: - Sync
    
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.syncGameState()
            }
        }
    }
    
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    private func syncGameState() async {
        guard let game = currentGame,
              let gameRecordName = game.cloudKitRecordName,
              let currentPlayerRecordName = cloudKit.currentUserRecordName else {
            return
        }
        
        do {
            // Fetch all player states for this game from CloudKit
            let records = try await cloudKit.fetchPlayerStates(gameRecordName: gameRecordName)
            
            // Parse and update player states
            var updatedOtherPlayers: [PlayerGameState] = []
            var latestBoardData: String?
            
            for record in records {
                guard let playerRecordName = record["playerRecordName"] as? String else {
                    continue
                }
                
                // Skip current player
                if playerRecordName == currentPlayerRecordName {
                    continue
                }
                
                // Create/update PlayerGameState from CloudKit record
                let playerState = PlayerGameState(
                    playerRecordName: playerRecordName,
                    playerUsername: (record["playerUsername"] as? String) ?? "Unknown",
                    gameSession: game
                )
                
                // Update fields
                playerState.currentBoardData = (record["currentBoardData"] as? String) ?? "{}"
                playerState.score = (record["score"] as? Int) ?? 0
                playerState.correctGuesses = (record["correctGuesses"] as? Int) ?? 0
                playerState.incorrectGuesses = (record["incorrectGuesses"] as? Int) ?? 0
                playerState.cellsCompleted = (record["cellsCompleted"] as? [String]) ?? []
                playerState.joinedAt = (record["joinedAt"] as? Date) ?? Date()
                playerState.lastMoveAt = record["lastMoveAt"] as? Date
                
                updatedOtherPlayers.append(playerState)
                
                // Track the most recent board update
                if let lastMove = playerState.lastMoveAt {
                    if latestBoardData == nil || lastMove > (currentPlayerState?.lastMoveAt ?? Date.distantPast) {
                        latestBoardData = playerState.currentBoardData
                    }
                }
            }
            
            // Update other players array
            await MainActor.run {
                self.otherPlayers = updatedOtherPlayers
            }
            
            // Update current board with latest moves from other players
            if let latestData = latestBoardData,
               let updatedBoard = SudokuBoard.fromJSONString(latestData) {
                await MainActor.run {
                    // Merge boards - prefer cells that have been filled by any player
                    if var currentBoardState = self.currentBoard {
                        for row in 0..<9 {
                            for col in 0..<9 {
                                let updatedCell = updatedBoard[row, col]
                                let currentCell = currentBoardState[row, col]
                                
                                // If the updated board has a value and current doesn't, use it
                                if updatedCell.value != nil && currentCell.value == nil {
                                    currentBoardState[row, col] = updatedCell
                                }
                                // If someone else completed this cell, update the completion info
                                else if let completedBy = updatedCell.completedBy,
                                        completedBy != currentPlayerRecordName {
                                    currentBoardState[row, col].completedBy = completedBy
                                }
                            }
                        }
                        self.currentBoard = currentBoardState
                        
                        // Also update the game session's puzzle data
                        game.puzzleData = currentBoardState.toJSONString()
                    }
                }
            }
            
            // Check if game should be completed
            if let board = currentBoard, SudokuGenerator.isBoardComplete(board) {
                try await completeGame()
            }
            
        } catch {
            print("Error syncing game state: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    /// Cancel/abandon the game (typically when only one player)
    func cancelGame() async throws {
        guard let game = currentGame else {
            throw GameError.noActiveGame
        }
        
        // Mark game as abandoned
        game.status = .abandoned
        
        // Save locally
        try modelContext.save()
        
        // Update CloudKit
        try await cloudKit.updateGameSession(game)
        
        // Stop sync timer
        stopSyncTimer()
        
        // Send system message if in CloudKit
        if let gameRecordName = game.cloudKitRecordName,
           let playerRecordName = cloudKit.currentUserRecordName,
           let username = cloudKit.currentUserProfile?.username {
            let message = ChatMessage(
                senderRecordName: playerRecordName,
                senderUsername: username,
                content: "Game cancelled",
                messageType: .system,
                gameSession: game
            )
            try? await cloudKit.sendChatMessage(message, gameRecordName: gameRecordName)
        }
        
        // Clean up
        leaveGame()
    }
    
    func leaveGame() {
        stopSyncTimer()
        currentGame = nil
        currentPlayerState = nil
        currentBoard = nil
        solutionBoard = nil
        otherPlayers = []
        selectedCell = nil
        isGameActive = false
        gameStartTime = nil
    }
    
    /// Check if the current user is the only player in the game
    var isOnlyPlayer: Bool {
        return otherPlayers.isEmpty
    }
}

// MARK: - Errors

enum GameError: LocalizedError {
    case notAuthenticated
    case noActiveGame
    case cannotModifyFixedCell
    case cellAlreadyCompleted
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to play."
        case .noActiveGame:
            return "No active game found."
        case .cannotModifyFixedCell:
            return "Cannot modify a fixed cell."
        case .cellAlreadyCompleted:
            return "This cell has already been completed by another player."
        }
    }
}
