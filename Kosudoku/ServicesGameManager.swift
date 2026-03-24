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

/// Represents a visual effect to play on a cell after a move
struct CellEffect: Equatable {
    enum Kind { case correct, incorrect }
    let row: Int
    let col: Int
    let kind: Kind
    let value: Int        // the digit that was guessed
    let color: Color      // the player's color
    let id: UUID = UUID() // unique so SwiftUI detects each new effect
    
    static func == (lhs: CellEffect, rhs: CellEffect) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages the current game state and coordinates between local and CloudKit
@Observable
@MainActor
class GameManager {
    var currentGame: GameSession?
    var currentPlayerState: PlayerGameState?
    var currentBoard: SudokuBoard?
    var solutionBoard: SudokuBoard?
    var otherPlayers: [PlayerGameState] = []
    
    var selectedCell: (row: Int, col: Int)? {
        didSet {
            // Push selection change to CloudKit (debounced via the flag)
            selectionDirty = true
        }
    }
    var isGameActive = false
    var gameStartTime: Date?
    var playerColorMap: [String: PlayerColor] = [:]
    var lastCellEffect: CellEffect?
    
    private var selectionDirty = false
    private var isSyncing = false
    private var isMakingMove = false
    
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
        print("🎮 GameManager.createGame called")
        
        guard let hostRecordName = cloudKit.currentUserRecordName else {
            print("❌ Not authenticated - no user record name")
            print("   isAuthenticated: \(cloudKit.isAuthenticated)")
            print("   currentUserProfile: \(cloudKit.currentUserProfile?.username ?? "nil")")
            throw GameError.notAuthenticated
        }
        
        print("✅ User authenticated: \(hostRecordName)")
        
        // Generate puzzle
        print("🎮 Generating puzzle...")
        let (puzzle, solution) = SudokuGenerator.generatePuzzle(difficulty: difficulty)
        print("✅ Puzzle generated")
        
        // Create game session
        print("🎮 Creating game session object...")
        let session = GameSession(
            hostRecordName: hostRecordName,
            difficulty: difficulty,
            puzzleData: puzzle.toJSONString(),
            solutionData: solution.toJSONString(),
            invitedPlayers: invitedPlayers
        )
        print("✅ Game session object created")
        
        // Save to CloudKit
        print("🎮 Saving to CloudKit...")
        do {
            try await cloudKit.createGameSession(session)
            print("✅ Saved to CloudKit, record name: \(session.cloudKitRecordName ?? "nil")")
        } catch {
            print("❌ Failed to save to CloudKit: \(error)")
            print("   Error type: \(type(of: error))")
            throw error
        }
        
        // Save locally
        print("🎮 Saving locally to SwiftData...")
        modelContext.insert(session)
        do {
            try modelContext.save()
            print("✅ Saved locally")
        } catch {
            print("❌ Failed to save locally: \(error)")
            throw error
        }
        
        // Join the game as host
        print("🎮 Joining game as host...")
        try await joinGame(session)
        print("✅ Joined game")
        
        currentGame = session
        currentBoard = puzzle
        solutionBoard = solution
        
        print("✅ GameManager.createGame completed successfully")
    }
    
    // MARK: - Game Join/Leave
    
    /// Join an existing game (or rejoin if already joined)
    func joinGame(_ session: GameSession) async throws {
        guard let playerRecordName = cloudKit.currentUserRecordName,
              let username = cloudKit.currentUserProfile?.username else {
            throw GameError.notAuthenticated
        }
        
        var playerState: PlayerGameState
        
        // Check if we already have a PlayerGameState for this game in CloudKit
        if let gameRecordName = session.cloudKitRecordName {
            let existingRecords = try await cloudKit.fetchPlayerStates(gameRecordName: gameRecordName)
            if let existingRecord = existingRecords.first(where: {
                ($0["playerRecordName"] as? String) == playerRecordName
            }) {
                // Reuse existing player state
                playerState = PlayerGameState(
                    playerRecordName: playerRecordName,
                    playerUsername: username,
                    gameSession: session
                )
                playerState.cloudKitRecordName = existingRecord.recordID.recordName
                playerState.score = (existingRecord["score"] as? Int) ?? 0
                playerState.correctGuesses = (existingRecord["correctGuesses"] as? Int) ?? 0
                playerState.incorrectGuesses = (existingRecord["incorrectGuesses"] as? Int) ?? 0
                playerState.cellsCompleted = (existingRecord["cellsCompleted"] as? [String]) ?? []
                playerState.currentBoardData = (existingRecord["currentBoardData"] as? String) ?? "{}"
                playerState.joinedAt = (existingRecord["joinedAt"] as? Date) ?? Date()
                playerState.lastMoveAt = existingRecord["lastMoveAt"] as? Date
                print("🎮 Found existing PlayerGameState in CloudKit, reusing")
            } else {
                // Create new player state
                playerState = PlayerGameState(
                    playerRecordName: playerRecordName,
                    playerUsername: username,
                    gameSession: session
                )
                try await cloudKit.savePlayerState(playerState, gameRecordName: gameRecordName)
                print("🎮 Created new PlayerGameState in CloudKit")
            }
            
            // Subscribe to game updates (non-critical)
            try? await cloudKit.subscribeToGameUpdates(gameRecordName: gameRecordName)
            
            // Subscribe to chat notifications for this game
            await ChatNotificationManager.shared.subscribeToGameChat(gameRecordName: gameRecordName)
            
            // If the game is already active, fetch the latest puzzleData from CloudKit
            if session.status == .active {
                if let record = try? await cloudKit.fetchGameSession(recordName: gameRecordName),
                   let latestPuzzleData = record["puzzleData"] as? String {
                    session.puzzleData = latestPuzzleData
                }
            }
        } else {
            // No CloudKit record name — create locally only
            playerState = PlayerGameState(
                playerRecordName: playerRecordName,
                playerUsername: username,
                gameSession: session
            )
        }
        
        // Always insert the player state into the context so SwiftData
        // tracks mutations made during makeMove (score, cellsCompleted, etc.).
        // SwiftData handles duplicates via the @Attribute(.unique) id.
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
        
        // Compute player color assignments
        recomputeColorMap()
        
        // If the game is already active, start the sync timer
        if session.status == .active {
            gameStartTime = session.startedAt ?? Date()
            isGameActive = true
            startSyncTimer()
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
        guard !isMakingMove else { return }
        isMakingMove = true
        defer { isMakingMove = false }
        
        guard let game = currentGame,
              let playerState = currentPlayerState,
              var board = currentBoard,
              let solution = solutionBoard else {
            throw GameError.noActiveGame
        }
        
        // Validate bounds
        guard row >= 0, row < 9, col >= 0, col < 9, value >= 1, value <= 9 else {
            return
        }
        
        // Check if cell is fixed
        if board[row, col].isFixed {
            throw GameError.cannotModifyFixedCell
        }
        
        // Fetch the latest board from CloudKit before making the move.
        // This prevents overwriting the other player's moves and catches
        // cells that were completed since the last sync.
        if let gameRecordName = game.cloudKitRecordName {
            if let gameRecord = try? await cloudKit.fetchGameSession(recordName: gameRecordName),
               let cloudPuzzleData = gameRecord["puzzleData"] as? String,
               let cloudBoard = SudokuBoard.fromJSONString(cloudPuzzleData) {
                // Merge any moves from the other player into our local board
                for r in 0..<9 {
                    for c in 0..<9 {
                        let cloudCell = cloudBoard[r, c]
                        let localCell = board[r, c]
                        if cloudCell.value != nil && localCell.value == nil {
                            board[r, c] = cloudCell
                        } else if let cb = cloudCell.completedBy, localCell.completedBy == nil {
                            board[r, c].completedBy = cb
                            if localCell.value == nil {
                                board[r, c].value = cloudCell.value
                            }
                        }
                    }
                }
                currentBoard = board
            }
        }
        
        // Re-check if the cell was already completed by another player
        // (may have been filled by the fresh CloudKit data above)
        if let completedBy = board[row, col].completedBy,
           completedBy != playerState.playerRecordName {
            // Update the game's puzzle data so the UI reflects the merged board
            game.puzzleData = board.toJSONString()
            throw GameError.cellAlreadyCompleted
        }
        
        // If the cell already has a value (e.g. the other player just filled it),
        // don't allow overwriting
        if board[row, col].value != nil {
            game.puzzleData = board.toJSONString()
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
            
            // Play correct chime and trigger visual effect
            GameSoundManager.shared.playCorrectSound()
            let effectColor = playerColorMap[playerState.playerRecordName]?.color ?? PlayerColor.coral.color
            lastCellEffect = CellEffect(row: row, col: col, kind: .correct, value: value, color: effectColor)
            
        } else {
            // Incorrect guess
            playerState.incorrectGuesses += 1
            playerState.score += ScoringSystem.pointsForIncorrectGuess()
            playerState.lastMoveAt = Date()
            
            // Play incorrect buzzer and trigger visual effect
            GameSoundManager.shared.playIncorrectSound()
            let effectColor = playerColorMap[playerState.playerRecordName]?.color ?? PlayerColor.coral.color
            lastCellEffect = CellEffect(row: row, col: col, kind: .incorrect, value: value, color: effectColor)
        }
        
        // Save locally
        try modelContext.save()
        
        // Sync to CloudKit (non-critical — don't crash if CloudKit fails)
        if let gameRecordName = game.cloudKitRecordName {
            do {
                try await cloudKit.savePlayerState(playerState, gameRecordName: gameRecordName)
                try await cloudKit.updateGameSession(game)
            } catch {
                print("⚠️ CloudKit sync after move failed (will retry on next sync): \(error.localizedDescription)")
            }
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
        
        // Guard against running twice (e.g., from both makeMove and syncGameState)
        guard game.status != .completed else { return }
        
        game.status = .completed
        game.completedAt = Date()
        isGameActive = false
        
        // Calculate final score for this game only
        let gameScore: Int
        if let startTime = gameStartTime {
            let timeElapsed = Date().timeIntervalSince(startTime)
            gameScore = ScoringSystem.calculateFinalScore(
                correctGuesses: playerState.correctGuesses,
                incorrectGuesses: playerState.incorrectGuesses,
                cellsCompleted: playerState.cellsCompleted.count,
                difficulty: game.difficulty,
                timeElapsed: timeElapsed,
                finishPosition: 1 // TODO: Determine actual position
            )
        } else {
            // Fallback: use the accumulated score from gameplay
            gameScore = playerState.score
        }
        playerState.score = gameScore
        
        // Update user profile stats (add only the game score, not the total)
        if let profile = cloudKit.currentUserProfile {
            profile.totalScore += gameScore
            profile.gamesPlayed += 1
            profile.gamesWon += 1
        }
        
        // Save locally first so stats persist regardless of CloudKit
        try modelContext.save()
        
        // Sync to CloudKit (don't let failures lose local data)
        if let profile = cloudKit.currentUserProfile {
            try? await cloudKit.saveUserProfile(profile)
        }
        try? await cloudKit.updateGameSession(game)
        
        // Stop sync timer
        stopSyncTimer()
    }
    
    // MARK: - Player Colors
    
    private func recomputeColorMap() {
        var all: [PlayerGameState] = otherPlayers
        if let current = currentPlayerState {
            all.append(current)
        }
        playerColorMap = PlayerColorAssigner.assign(players: all)
    }
    
    // MARK: - Sync
    
    private func startSyncTimer() {
        // Stop any existing timer first
        stopSyncTimer()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task {
                await self?.syncGameState()
            }
        }
    }
    
    /// Trigger an immediate sync (e.g., when the game view appears)
    func triggerSync() {
        Task {
            await syncGameState()
        }
    }
    
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    private func syncGameState() async {
        // Guard against overlapping sync calls
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        guard let game = currentGame,
              let gameRecordName = game.cloudKitRecordName,
              let currentPlayerRecordName = cloudKit.currentUserRecordName else {
            return
        }
        
        // Push current player's selected cell to CloudKit only when it changed
        // and no move is currently being saved (to avoid conflicting writes)
        if selectionDirty, !isMakingMove,
           let playerState = currentPlayerState,
           playerState.cloudKitRecordName != nil {
            playerState.selectedRow = selectedCell?.row
            playerState.selectedCol = selectedCell?.col
            try? await cloudKit.savePlayerState(playerState, gameRecordName: gameRecordName)
            selectionDirty = false
        }
        
        do {
            // Fetch game session and player states in parallel for faster sync
            async let gameRecordTask = cloudKit.fetchGameSession(recordName: gameRecordName)
            async let playerRecordsTask = cloudKit.fetchPlayerStates(gameRecordName: gameRecordName)
            
            let gameRecord = try await gameRecordTask
            let cloudPuzzleData = gameRecord["puzzleData"] as? String
            let records = try await playerRecordsTask
            
            // Parse and update player states (deduplicate by playerRecordName,
            // keeping only the most recently updated record for each player)
            var updatedOtherPlayers: [PlayerGameState] = []
            var seenPlayers: Set<String> = []
            
            // Sort records so the most recently modified comes first
            let sortedRecords = records.sorted {
                ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
            }
            
            for record in sortedRecords {
                guard let playerRecordName = record["playerRecordName"] as? String else {
                    continue
                }
                
                // Skip current player
                if playerRecordName == currentPlayerRecordName {
                    continue
                }
                
                // Skip duplicates — keep only the first (most recent) record per player
                guard seenPlayers.insert(playerRecordName).inserted else {
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
                playerState.selectedRow = record["selectedRow"] as? Int
                playerState.selectedCol = record["selectedCol"] as? Int
                
                updatedOtherPlayers.append(playerState)
            }
            
            // Update other players array and recompute color assignments
            await MainActor.run {
                self.otherPlayers = updatedOtherPlayers
                self.recomputeColorMap()
            }
            
            // Merge the authoritative board from CloudKit with the local board.
            // The CloudKit GameSession puzzleData is updated by whichever player
            // makes a correct move, so it always reflects the latest state.
            if let latestData = cloudPuzzleData,
               let cloudBoard = SudokuBoard.fromJSONString(latestData) {
                await MainActor.run {
                    if var currentBoardState = self.currentBoard {
                        for row in 0..<9 {
                            for col in 0..<9 {
                                let cloudCell = cloudBoard[row, col]
                                let localCell = currentBoardState[row, col]
                                
                                // If the cloud board has a value that the local board doesn't, use it
                                if cloudCell.value != nil && localCell.value == nil {
                                    currentBoardState[row, col] = cloudCell
                                }
                                // If someone else completed this cell, update the completion info
                                else if let completedBy = cloudCell.completedBy,
                                        completedBy != currentPlayerRecordName,
                                        localCell.completedBy == nil {
                                    currentBoardState[row, col].completedBy = completedBy
                                }
                            }
                        }
                        self.currentBoard = currentBoardState
                        game.puzzleData = currentBoardState.toJSONString()
                    }
                }
            }
            
            // Check game status from CloudKit (e.g. other player completed it)
            if let statusRaw = gameRecord["status"] as? String,
               let status = GameStatus(rawValue: statusRaw),
               status == .completed,
               game.status != .completed {
                game.status = .completed
                game.completedAt = gameRecord["completedAt"] as? Date
                
                // Update this player's profile stats (the completing player
                // already updated theirs in completeGame())
                if let playerState = currentPlayerState,
                   let profile = cloudKit.currentUserProfile {
                    // Calculate final score for this player
                    if let startTime = gameStartTime {
                        let timeElapsed = Date().timeIntervalSince(startTime)
                        let gameScore = ScoringSystem.calculateFinalScore(
                            correctGuesses: playerState.correctGuesses,
                            incorrectGuesses: playerState.incorrectGuesses,
                            cellsCompleted: playerState.cellsCompleted.count,
                            difficulty: game.difficulty,
                            timeElapsed: timeElapsed,
                            finishPosition: nil
                        )
                        playerState.score = gameScore
                    }
                    
                    profile.totalScore += playerState.score
                    profile.gamesPlayed += 1
                    // Don't count as a win — the other player completed it
                    
                    try? await cloudKit.saveUserProfile(profile)
                }
                
                try? modelContext.save()
                await MainActor.run {
                    self.isGameActive = false
                }
                stopSyncTimer()
                return
            }
            
            // Check if board is complete locally
            if let board = currentBoard, SudokuGenerator.isBoardComplete(board) {
                try await completeGame()
            }
            
        } catch {
            print("❌ Error syncing game state: \(error)")
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
    
    /// Load a completed game for viewing (read-only, no sync timer)
    func viewCompletedGame(_ session: GameSession) async {
        currentGame = session
        currentPlayerState = nil
        otherPlayers = []
        selectedCell = nil
        isGameActive = false
        gameStartTime = session.startedAt
        
        if let board = SudokuBoard.fromJSONString(session.puzzleData) {
            currentBoard = board
        }
        if let solution = SudokuBoard.fromJSONString(session.solutionData) {
            solutionBoard = solution
        }
        
        // Fetch player states from CloudKit to show final standings
        guard let gameRecordName = session.cloudKitRecordName else { return }
        do {
            let records = try await cloudKit.fetchPlayerStates(gameRecordName: gameRecordName)
            let currentUserRecordName = cloudKit.currentUserRecordName
            
            var allPlayers: [PlayerGameState] = []
            for record in records {
                guard let playerRecordName = record["playerRecordName"] as? String else { continue }
                
                let state = PlayerGameState(
                    playerRecordName: playerRecordName,
                    playerUsername: (record["playerUsername"] as? String) ?? "Unknown",
                    gameSession: session
                )
                state.score = (record["score"] as? Int) ?? 0
                state.correctGuesses = (record["correctGuesses"] as? Int) ?? 0
                state.incorrectGuesses = (record["incorrectGuesses"] as? Int) ?? 0
                state.cellsCompleted = (record["cellsCompleted"] as? [String]) ?? []
                state.joinedAt = (record["joinedAt"] as? Date) ?? Date()
                
                if playerRecordName == currentUserRecordName {
                    currentPlayerState = state
                } else {
                    allPlayers.append(state)
                }
            }
            
            otherPlayers = allPlayers
            recomputeColorMap()
        } catch {
            print("⚠️ Failed to fetch player states for completed game: \(error.localizedDescription)")
        }
    }
    
    func leaveGame() {
        // Unsubscribe from chat notifications for this game
        if let recordName = currentGame?.cloudKitRecordName {
            let subID = "chat-game-\(recordName)"
            Task {
                await ChatNotificationManager.shared.unsubscribeFromChat(subscriptionID: subID)
            }
        }
        
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
