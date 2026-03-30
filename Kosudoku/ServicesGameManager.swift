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

extension Notification.Name {
    static let gameEndResultSet = Notification.Name("gameEndResultSet")
}

/// Represents a visual effect to play on a cell after a move
struct CellEffect: Equatable {
    enum Kind { case correct, incorrect }
    let row: Int
    let col: Int
    let kind: Kind
    let value: Int        // the digit that was guessed
    let color: Color      // the player's color
    let points: Int       // points earned (+) or lost (-) for the floating label
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
    
    /// Result shown at game end (nil while playing)
    enum GameEndResult { case won, lost }
    var gameEndResult: GameEndResult?
    
    // Lobby state
    var acceptedPlayers: [PlayerGameState] = []
    var isWaitingInLobby = false
    
    private var selectionDirty = false
    private var isSyncing = false
    private var isMakingMove = false
    private var isJoining = false
    
    private let cloudKit = CloudKitService.shared
    private let modelContext: ModelContext
    
    // Timer for periodic sync
    private var syncTimer: Timer?
    private var lobbyTimer: Timer?
    
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
        guard !isJoining else { return }
        isJoining = true
        defer { isJoining = false }
        
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
            
            // Subscribe to chat notifications and start monitoring for this game
            await ChatNotificationManager.shared.subscribeToGameChat(gameRecordName: gameRecordName)
            ChatNotificationManager.shared.monitorGameChat(gameRecordName: gameRecordName)
            
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
        
        // If the game is still waiting, start lobby polling
        if session.status == .waiting {
            startLobbyPolling()
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
    
    // MARK: - Lobby
    
    /// Start polling CloudKit for lobby state (who has accepted, game status changes)
    func startLobbyPolling() {
        isWaitingInLobby = true
        stopLobbyPolling()
        lobbyTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task {
                await self?.pollLobbyState()
            }
        }
        // Run immediately once
        Task { await pollLobbyState() }
    }
    
    /// Poll CloudKit for lobby state changes
    private func pollLobbyState() async {
        guard let game = currentGame,
              let gameRecordName = game.cloudKitRecordName else { return }
        
        // Check if game status changed on CloudKit (e.g. host started or cancelled)
        if let gameRecord = try? await cloudKit.fetchGameSession(recordName: gameRecordName),
           let statusRaw = gameRecord["status"] as? String,
           let status = GameStatus(rawValue: statusRaw) {
            
            // Update declined players from CloudKit
            if let declined = gameRecord["declinedPlayers"] as? [String] {
                game.declinedPlayers = declined
            }
            
            if status == .active && game.status == .waiting {
                // Game was started (by host or auto-start)
                game.status = .active
                game.startedAt = gameRecord["startedAt"] as? Date ?? Date()
                gameStartTime = game.startedAt
                isGameActive = true
                isWaitingInLobby = false
                try? modelContext.save()
                stopLobbyPolling()
                startSyncTimer()
                return
            }
            if status == .abandoned && game.status == .waiting {
                game.status = .abandoned
                isWaitingInLobby = false
                try? modelContext.save()
                stopLobbyPolling()
                return
            }
        }
        
        // Fetch player states to see who has joined
        do {
            let records = try await cloudKit.fetchPlayerStates(gameRecordName: gameRecordName)
            
            var seenPlayers: Set<String> = []
            var accepted: [PlayerGameState] = []
            
            let sortedRecords = records.sorted {
                ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
            }
            
            for record in sortedRecords {
                guard let playerRecordName = record["playerRecordName"] as? String else { continue }
                guard seenPlayers.insert(playerRecordName).inserted else { continue }
                
                let state = PlayerGameState(
                    playerRecordName: playerRecordName,
                    playerUsername: (record["playerUsername"] as? String) ?? "Unknown",
                    gameSession: game
                )
                state.joinedAt = (record["joinedAt"] as? Date) ?? Date()
                accepted.append(state)
            }
            
            acceptedPlayers = accepted
            
            // Auto-start: only the host triggers to avoid race conditions
            guard game.hostRecordName == cloudKit.currentUserRecordName else { return }
            
            let invitedSet = Set(game.invitedPlayers)
            let acceptedSet = Set(accepted.map { $0.playerRecordName })
            
            if invitedSet.isSubset(of: acceptedSet) {
                // All invited players have accepted — auto-start
                try await startGame()
                isWaitingInLobby = false
                stopLobbyPolling()
            }
        } catch {
            // Non-critical, will retry next poll
        }
    }
    
    func stopLobbyPolling() {
        lobbyTimer?.invalidate()
        lobbyTimer = nil
    }
    
    /// Host manually starts the game before all players have accepted
    func forceStartGame() async throws {
        try await startGame()
        isWaitingInLobby = false
        stopLobbyPolling()
    }
    
    /// Invited player declines a game invitation
    func declineGame(_ session: GameSession) async throws {
        guard let playerRecordName = cloudKit.currentUserRecordName else {
            throw GameError.notAuthenticated
        }
        
        if !session.declinedPlayers.contains(playerRecordName) {
            session.declinedPlayers.append(playerRecordName)
        }
        try await cloudKit.updateGameSession(session)
        try modelContext.save()
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
            lastCellEffect = CellEffect(row: row, col: col, kind: .correct, value: value, color: effectColor, points: points)
            
        } else {
            // Incorrect guess
            playerState.incorrectGuesses += 1
            playerState.score += ScoringSystem.pointsForIncorrectGuess()
            playerState.lastMoveAt = Date()
            
            // Play incorrect buzzer and trigger visual effect
            GameSoundManager.shared.playIncorrectSound()
            let effectColor = playerColorMap[playerState.playerRecordName]?.color ?? PlayerColor.coral.color
            lastCellEffect = CellEffect(row: row, col: col, kind: .incorrect, value: value, color: effectColor, points: ScoringSystem.pointsForIncorrectGuess())
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
    ///
    /// The completing player is the single authority for final scores:
    /// they calculate end-game bonuses (speed, first place) for ALL
    /// players and save everything to CloudKit. Non-completing players
    /// simply read their final score from CloudKit in `syncGameState()`.
    private func completeGame() async throws {
        guard let game = currentGame,
              let playerState = currentPlayerState else {
            throw GameError.noActiveGame
        }
        
        // Guard against running twice (e.g., from both makeMove and syncGameState).
        // Check both status and gameEndResult since we defer setting .completed.
        guard game.status != .completed, gameEndResult == nil else { return }
        
        // Mark completed locally but defer setting game.status until after
        // gameEndResult is set, so the view doesn't switch away before
        // the end-game overlay can trigger.
        game.completedAt = Date()
        
        let gameRecordName = game.cloudKitRecordName
        let completionTime = Date()
        let gameStart = gameStartTime ?? game.startedAt ?? completionTime
        let timeElapsed = completionTime.timeIntervalSince(gameStart)
        
        // Gather all players (current + others) to determine final standings
        var allPlayerStates: [(state: PlayerGameState, isLocal: Bool)] = []
        allPlayerStates.append((playerState, true))
        
        // Fetch freshest other-player data from CloudKit for accurate cell counts
        if let grn = gameRecordName {
            if let records = try? await cloudKit.fetchPlayerStates(gameRecordName: grn) {
                let currentRecordName = cloudKit.currentUserRecordName
                var seenPlayers: Set<String> = []
                let sorted = records.sorted {
                    ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
                }
                for record in sorted {
                    guard let prn = record["playerRecordName"] as? String else { continue }
                    if prn == currentRecordName { continue }
                    guard seenPlayers.insert(prn).inserted else { continue }
                    
                    let ps = PlayerGameState(
                        playerRecordName: prn,
                        playerUsername: (record["playerUsername"] as? String) ?? "Unknown",
                        gameSession: game
                    )
                    ps.cloudKitRecordName = record.recordID.recordName
                    ps.score = (record["score"] as? Int) ?? 0
                    ps.correctGuesses = (record["correctGuesses"] as? Int) ?? 0
                    ps.incorrectGuesses = (record["incorrectGuesses"] as? Int) ?? 0
                    ps.cellsCompleted = (record["cellsCompleted"] as? [String]) ?? []
                    ps.joinedAt = (record["joinedAt"] as? Date) ?? Date()
                    ps.lastMoveAt = record["lastMoveAt"] as? Date
                    allPlayerStates.append((ps, false))
                }
            }
        }
        
        // First pass: apply speed bonus to get pre-position scores
        for entry in allPlayerStates {
            let ps = entry.state
            let speedPoints = ScoringSystem.speedBonus(
                cellsCompleted: ps.cellsCompleted.count,
                timeElapsed: timeElapsed
            )
            ps.score += speedPoints
        }
        
        // Rank by score, then fewer incorrect guesses, then earliest last move
        let ranked = allPlayerStates.shuffled().sorted {
            if $0.state.score != $1.state.score {
                return $0.state.score > $1.state.score
            }
            if $0.state.incorrectGuesses != $1.state.incorrectGuesses {
                return $0.state.incorrectGuesses < $1.state.incorrectGuesses
            }
            // Earlier lastMoveAt wins (finished their moves sooner)
            let t0 = $0.state.lastMoveAt ?? .distantFuture
            let t1 = $1.state.lastMoveAt ?? .distantFuture
            return t0 < t1
        }
        
        // Second pass: apply position bonus based on score ranking, then save
        for (index, entry) in ranked.enumerated() {
            let ps = entry.state
            let position = index + 1
            
            switch position {
            case 1: ps.score += ScoringSystem.firstPlaceBonus
            case 2: ps.score += ScoringSystem.secondPlaceBonus
            case 3: ps.score += ScoringSystem.thirdPlaceBonus
            default: break
            }
            
            ps.score = max(0, ps.score)
            
            // Save every player's final score to CloudKit
            if let grn = gameRecordName {
                try? await cloudKit.savePlayerState(ps, gameRecordName: grn)
            }
        }
        
        // Determine if *this* player won (first in rankings)
        let isWinner = ranked.first?.state.playerRecordName == playerState.playerRecordName
        let result: GameEndResult = isWinner ? .won : .lost
        
        // Update user profile stats (use the already-updated playerState.score)
        let isSoloGame = allPlayerStates.count <= 1
        if let profile = cloudKit.currentUserProfile {
            profile.totalScore += playerState.score
            profile.gamesPlayed += 1
            if isWinner {
                profile.gamesWon += 1
                // Award +1 quicket for winning a multiplayer game only
                if !isSoloGame {
                    profile.quickets += 1
                }
            }
        }
        
        // Save locally (but do NOT set game.status = .completed yet —
        // that would switch the view to CompletedGameResultsView before
        // the end-game overlay animations can play).
        try modelContext.save()
        
        // Sync profile to CloudKit
        if let profile = cloudKit.currentUserProfile {
            try? await cloudKit.saveUserProfile(profile)
        }
        
        // Stop sync timer so it doesn't race with the animation sequence
        stopSyncTimer()
        
        // Set gameEndResult — this fires onChange(of: gameEndResult) in
        // GameView, triggering the overlay + quicket animation sequence.
        gameEndResult = result
        NotificationCenter.default.post(name: .gameEndResultSet, object: nil)
        
        // Push completed status to CloudKit directly on the record,
        // WITHOUT changing the local game.status (which would switch
        // the view to CompletedGameResultsView too early).
        if let grn = gameRecordName {
            Task {
                try? await self.cloudKit.updateGameSessionStatus(recordName: grn, status: .completed, completedAt: game.completedAt)
            }
        }
        
        // After the animation sequence completes (~6s), mark the game
        // as completed locally so the view transitions to results.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            guard let self else { return }
            self.currentGame?.status = .completed
            self.isGameActive = false
        }
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
                game.completedAt = gameRecord["completedAt"] as? Date
                
                // Stop sync timer first to prevent further syncs
                stopSyncTimer()
                
                // The completing player already calculated final scores for
                // everyone and saved them to CloudKit. Do a fresh fetch of
                // player states to get the authoritative bonus-applied scores
                // (the batch we already have may be stale due to CloudKit
                // eventual consistency).
                if let playerState = currentPlayerState {
                    let freshRecords = (try? await cloudKit.fetchPlayerStates(gameRecordName: gameRecordName)) ?? []
                    
                    // Deduplicate — keep only the most recently modified record per player
                    let freshSorted = freshRecords.sorted {
                        ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
                    }
                    var freshSeen: Set<String> = []
                    var freshOtherPlayers: [PlayerGameState] = []
                    
                    for record in freshSorted {
                        guard let prn = record["playerRecordName"] as? String else { continue }
                        guard freshSeen.insert(prn).inserted else { continue }
                        
                        if prn == currentPlayerRecordName {
                            // Read our authoritative score
                            let cloudScore = (record["score"] as? Int) ?? playerState.score
                            playerState.score = cloudScore
                        } else {
                            let ps = PlayerGameState(
                                playerRecordName: prn,
                                playerUsername: (record["playerUsername"] as? String) ?? "Unknown",
                                gameSession: game
                            )
                            ps.score = (record["score"] as? Int) ?? 0
                            ps.correctGuesses = (record["correctGuesses"] as? Int) ?? 0
                            ps.incorrectGuesses = (record["incorrectGuesses"] as? Int) ?? 0
                            ps.cellsCompleted = (record["cellsCompleted"] as? [String]) ?? []
                            ps.joinedAt = (record["joinedAt"] as? Date) ?? Date()
                            freshOtherPlayers.append(ps)
                        }
                    }
                    
                    // Determine win/loss from final scores
                    let myScore = playerState.score
                    let maxOtherScore = freshOtherPlayers.map(\.score).max() ?? 0
                    let isWinner = freshOtherPlayers.isEmpty || myScore > maxOtherScore
                    
                    let isSoloGame = freshOtherPlayers.isEmpty
                    if let profile = cloudKit.currentUserProfile {
                        profile.totalScore += playerState.score
                        profile.gamesPlayed += 1
                        if isWinner {
                            profile.gamesWon += 1
                            // Award +1 quicket for winning a multiplayer game only
                            if !isSoloGame {
                                profile.quickets += 1
                            }
                        }
                        try? await cloudKit.saveUserProfile(profile)
                    }
                    
                    try? modelContext.save()
                    await MainActor.run {
                        self.otherPlayers = freshOtherPlayers
                        self.recomputeColorMap()
                        // Set gameEndResult to trigger the animation sequence.
                        // Do NOT set game.status = .completed yet — that would
                        // switch the view to CompletedGameResultsView before
                        // the overlay animations can play.
                        self.gameEndResult = isWinner ? .won : .lost
                        NotificationCenter.default.post(name: .gameEndResultSet, object: nil)
                    }
                    
                    // Delay setting completed status and deactivating game
                    // until the animation sequence finishes (~6s).
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
                        guard let self else { return }
                        self.currentGame?.status = .completed
                        self.isGameActive = false
                    }
                } else {
                    await MainActor.run {
                        game.status = .completed
                        self.isGameActive = false
                    }
                }
                
                return
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
            
            // Deduplicate by playerRecordName — keep the most recently modified
            // record for each player (there may be duplicates from race conditions)
            let sortedRecords = records.sorted {
                ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
            }
            var seenPlayers: Set<String> = []
            var allPlayers: [PlayerGameState] = []
            
            for record in sortedRecords {
                guard let playerRecordName = record["playerRecordName"] as? String else { continue }
                
                // Skip duplicates — keep only the first (most recent) record per player
                guard seenPlayers.insert(playerRecordName).inserted else { continue }
                
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
        stopLobbyPolling()
        currentGame = nil
        currentPlayerState = nil
        currentBoard = nil
        solutionBoard = nil
        otherPlayers = []
        acceptedPlayers = []
        selectedCell = nil
        isGameActive = false
        isWaitingInLobby = false
        gameStartTime = nil
        gameEndResult = nil
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
