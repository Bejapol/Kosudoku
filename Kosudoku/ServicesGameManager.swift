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
    
    /// Guards against applying end-game profile stats more than once per game
    private var hasAppliedEndGameStats = false
    
    // Lobby state
    var acceptedPlayers: [PlayerGameState] = []
    var isWaitingInLobby = false
    
    /// Countdown seconds visible in the lobby (nil = no countdown, 5..0 = counting)
    var countdownSeconds: Int? = nil
    
    private var selectionDirty = false
    private var isSyncing = false
    private var isMakingMove = false
    private var isJoining = false
    
    private let cloudKit = CloudKitService.shared
    private let modelContext: ModelContext
    
    // Timer for periodic sync
    private var syncTimer: Timer?
    private var lobbyTimer: Timer?
    private var countdownTimer: Timer?
    
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
                playerState.customColorRawValue = existingRecord["customColorRawValue"] as? Int
                print("🎮 Found existing PlayerGameState in CloudKit, reusing")
            } else {
                // Create new player state
                playerState = PlayerGameState(
                    playerRecordName: playerRecordName,
                    playerUsername: username,
                    gameSession: session
                )
                playerState.customColorRawValue = cloudKit.currentUserProfile?.customColorRawValue
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
            playerState.customColorRawValue = cloudKit.currentUserProfile?.customColorRawValue
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
                countdownSeconds = nil
                countdownTimer?.invalidate()
                countdownTimer = nil
                try? modelContext.save()
                stopLobbyPolling()
                startSyncTimer()
                return
            }
            if status == .abandoned && game.status == .waiting {
                game.status = .abandoned
                isWaitingInLobby = false
                countdownSeconds = nil
                countdownTimer?.invalidate()
                countdownTimer = nil
                try? modelContext.save()
                stopLobbyPolling()
                return
            }
            
            // Check for countdown started by host (non-host path)
            if let countdownStart = gameRecord["countdownStartedAt"] as? Date,
               game.status == .waiting,
               countdownSeconds == nil {
                let elapsed = Date().timeIntervalSince(countdownStart)
                let remaining = max(0, 5 - Int(elapsed))
                if remaining > 0 {
                    countdownSeconds = remaining
                    startCountdownTimer()
                }
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
            
            // Auto-start countdown: only the host triggers to avoid race conditions
            guard game.hostRecordName == cloudKit.currentUserRecordName else { return }
            
            let invitedSet = Set(game.invitedPlayers)
            let acceptedSet = Set(accepted.map { $0.playerRecordName })
            
            if invitedSet.isSubset(of: acceptedSet) && countdownSeconds == nil {
                // All invited players have accepted — start countdown
                game.countdownStartedAt = Date()
                try await cloudKit.updateGameSession(game)
                countdownSeconds = 5
                startCountdownTimer()
            }
        } catch {
            // Non-critical, will retry next poll
        }
    }
    
    func stopLobbyPolling() {
        lobbyTimer?.invalidate()
        lobbyTimer = nil
    }
    
    /// Start a 1-second countdown timer that decrements countdownSeconds until 0,
    /// then the host starts the game.
    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let current = self.countdownSeconds else { return }
                if current <= 1 {
                    self.countdownSeconds = 0
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                    // Host starts the game
                    if self.currentGame?.hostRecordName == self.cloudKit.currentUserRecordName {
                        try? await self.startGame()
                        self.isWaitingInLobby = false
                        self.stopLobbyPolling()
                    }
                    // Non-host: the next poll will detect .active status and transition
                } else {
                    self.countdownSeconds = current - 1
                }
            }
        }
    }
    
    /// Host manually starts the game before all players have accepted
    func forceStartGame() async throws {
        guard let game = currentGame else {
            throw GameError.noActiveGame
        }
        // Start countdown instead of immediately starting
        game.countdownStartedAt = Date()
        try await cloudKit.updateGameSession(game)
        countdownSeconds = 5
        startCountdownTimer()
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
        
        // Stop sync timer IMMEDIATELY to prevent syncGameState from racing
        // with score mutations (e.g., adding speed bonus a second time).
        stopSyncTimer()
        
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
                    ps.customColorRawValue = record["customColorRawValue"] as? Int
                    allPlayerStates.append((ps, false))
                }
            }
        }
        
        // Apply speed bonus to final scores
        for entry in allPlayerStates {
            let ps = entry.state
            let speedPoints = ScoringSystem.speedBonus(
                cellsCompleted: ps.cellsCompleted.count,
                timeElapsed: timeElapsed
            )
            ps.score += speedPoints
            ps.score = max(0, ps.score)
        }
        
        // Save every player's final score to CloudKit
        for entry in allPlayerStates {
            if let grn = gameRecordName {
                try? await cloudKit.savePlayerState(entry.state, gameRecordName: grn)
            }
        }
        
        // Determine if *this* player won.
        // Rank by: highest score → fewest incorrect guesses → earliest last move.
        // Ties on all criteria are treated as a win for both.
        let myScore = playerState.score
        let othersOnly = allPlayerStates.filter { !$0.isLocal }
        let isWinner: Bool
        if othersOnly.isEmpty {
            isWinner = true // solo game
        } else {
            isWinner = othersOnly.allSatisfy { other in
                let os = other.state
                if myScore != os.score { return myScore > os.score }
                if playerState.incorrectGuesses != os.incorrectGuesses {
                    return playerState.incorrectGuesses < os.incorrectGuesses
                }
                let myTime = playerState.lastMoveAt ?? .distantFuture
                let otherTime = os.lastMoveAt ?? .distantFuture
                return myTime <= otherTime
            }
        }
        let result: GameEndResult = isWinner ? .won : .lost
        
        // Update user profile stats (use the already-updated playerState.score)
        // Guard against double-counting if completeGame fires from multiple paths.
        let isSoloGame = allPlayerStates.count <= 1
        if !hasAppliedEndGameStats, let profile = cloudKit.currentUserProfile {
            hasAppliedEndGameStats = true
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
            var updatedOtherPlayers: [(recordName: String, username: String, currentBoardData: String, score: Int, correctGuesses: Int, incorrectGuesses: Int, cellsCompleted: [String], joinedAt: Date, lastMoveAt: Date?, selectedRow: Int?, selectedCol: Int?, customColorRawValue: Int?)] = []
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
                
                // Collect parsed data for this player
                updatedOtherPlayers.append((
                    recordName: playerRecordName,
                    username: (record["playerUsername"] as? String) ?? "Unknown",
                    currentBoardData: (record["currentBoardData"] as? String) ?? "{}",
                    score: (record["score"] as? Int) ?? 0,
                    correctGuesses: (record["correctGuesses"] as? Int) ?? 0,
                    incorrectGuesses: (record["incorrectGuesses"] as? Int) ?? 0,
                    cellsCompleted: (record["cellsCompleted"] as? [String]) ?? [],
                    joinedAt: (record["joinedAt"] as? Date) ?? Date(),
                    lastMoveAt: record["lastMoveAt"] as? Date,
                    selectedRow: record["selectedRow"] as? Int,
                    selectedCol: record["selectedCol"] as? Int,
                    customColorRawValue: record["customColorRawValue"] as? Int
                ))
            }
            
            // Update other players in-place to preserve SwiftUI identity
            // (creating new objects every sync would reset @State in child views,
            // causing sheets to close and views to flicker).
            await MainActor.run {
                // Build lookup of existing objects by playerRecordName
                var existingByName: [String: PlayerGameState] = [:]
                for player in self.otherPlayers {
                    existingByName[player.playerRecordName] = player
                }
                
                var result: [PlayerGameState] = []
                for data in updatedOtherPlayers {
                    let ps: PlayerGameState
                    if let existing = existingByName[data.recordName] {
                        // Update existing object in-place (same identity)
                        ps = existing
                    } else {
                        // New player — create once
                        ps = PlayerGameState(
                            playerRecordName: data.recordName,
                            playerUsername: data.username,
                            gameSession: game
                        )
                    }
                    ps.playerUsername = data.username
                    ps.currentBoardData = data.currentBoardData
                    ps.score = data.score
                    ps.correctGuesses = data.correctGuesses
                    ps.incorrectGuesses = data.incorrectGuesses
                    ps.cellsCompleted = data.cellsCompleted
                    ps.joinedAt = data.joinedAt
                    ps.lastMoveAt = data.lastMoveAt
                    ps.selectedRow = data.selectedRow
                    ps.selectedCol = data.selectedCol
                    ps.customColorRawValue = data.customColorRawValue
                    result.append(ps)
                }
                self.otherPlayers = result
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
            
            // After merging the cloud board, check if the puzzle is now
            // fully solved. This catches the case where both players fill
            // cells nearly simultaneously and neither player's makeMove
            // saw the complete board (due to CloudKit eventual consistency).
            if let board = currentBoard,
               SudokuGenerator.isBoardComplete(board),
               game.status != .completed,
               gameEndResult == nil {
                try await completeGame()
                return
            }
            
            // Check game status from CloudKit (e.g. other player completed it)
            if let statusRaw = gameRecord["status"] as? String,
               let status = GameStatus(rawValue: statusRaw),
               status == .completed,
               game.status != .completed {
                game.completedAt = gameRecord["completedAt"] as? Date
                
                // Stop sync timer first to prevent further syncs
                stopSyncTimer()

                // Re-fetch the game record to get the final puzzleData
                // (the one we already fetched may be stale and missing
                // the winning player's last move).
                if let finalGameRecord = try? await cloudKit.fetchGameSession(recordName: gameRecordName),
                   let finalPuzzleData = finalGameRecord["puzzleData"] as? String,
                   let finalBoard = SudokuBoard.fromJSONString(finalPuzzleData) {
                    await MainActor.run {
                        if var localBoard = self.currentBoard {
                            for r in 0..<9 {
                                for c in 0..<9 {
                                    let cloudCell = finalBoard[r, c]
                                    let localCell = localBoard[r, c]
                                    if cloudCell.value != nil && localCell.value == nil {
                                        localBoard[r, c] = cloudCell
                                    } else if let cb = cloudCell.completedBy, localCell.completedBy == nil {
                                        localBoard[r, c].completedBy = cb
                                    }
                                }
                            }
                            self.currentBoard = localBoard
                            game.puzzleData = localBoard.toJSONString()
                        }
                    }
                }

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
                    // Parsed data for other players (used for winner determination)
                    var freshData: [(recordName: String, username: String, score: Int, correctGuesses: Int, incorrectGuesses: Int, cellsCompleted: [String], joinedAt: Date, lastMoveAt: Date?)] = []
                    
                    for record in freshSorted {
                        guard let prn = record["playerRecordName"] as? String else { continue }
                        guard freshSeen.insert(prn).inserted else { continue }
                        
                        if prn == currentPlayerRecordName {
                            // Read our authoritative score and stats
                            playerState.score = (record["score"] as? Int) ?? playerState.score
                            playerState.incorrectGuesses = (record["incorrectGuesses"] as? Int) ?? playerState.incorrectGuesses
                            playerState.lastMoveAt = (record["lastMoveAt"] as? Date) ?? playerState.lastMoveAt
                        } else {
                            freshData.append((
                                recordName: prn,
                                username: (record["playerUsername"] as? String) ?? "Unknown",
                                score: (record["score"] as? Int) ?? 0,
                                correctGuesses: (record["correctGuesses"] as? Int) ?? 0,
                                incorrectGuesses: (record["incorrectGuesses"] as? Int) ?? 0,
                                cellsCompleted: (record["cellsCompleted"] as? [String]) ?? [],
                                joinedAt: (record["joinedAt"] as? Date) ?? Date(),
                                lastMoveAt: record["lastMoveAt"] as? Date
                            ))
                        }
                    }
                    
                    // Determine win/loss from final scores.
                    // Rank by: highest score → fewest incorrect guesses → earliest last move.
                    // Ties on all criteria are treated as a win for both.
                    let isWinner: Bool
                    if freshData.isEmpty {
                        isWinner = true
                    } else {
                        isWinner = freshData.allSatisfy { other in
                            if playerState.score != other.score { return playerState.score > other.score }
                            if playerState.incorrectGuesses != other.incorrectGuesses {
                                return playerState.incorrectGuesses < other.incorrectGuesses
                            }
                            let myTime = playerState.lastMoveAt ?? .distantFuture
                            let otherTime = other.lastMoveAt ?? .distantFuture
                            return myTime <= otherTime
                        }
                    }
                    
                    let isSoloGame = freshData.isEmpty
                    if !hasAppliedEndGameStats, let profile = cloudKit.currentUserProfile {
                        hasAppliedEndGameStats = true
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
                        // Update existing objects in-place to preserve SwiftUI identity
                        var existingByName: [String: PlayerGameState] = [:]
                        for player in self.otherPlayers {
                            existingByName[player.playerRecordName] = player
                        }
                        var result: [PlayerGameState] = []
                        for data in freshData {
                            let ps: PlayerGameState
                            if let existing = existingByName[data.recordName] {
                                ps = existing
                            } else {
                                ps = PlayerGameState(
                                    playerRecordName: data.recordName,
                                    playerUsername: data.username,
                                    gameSession: game
                                )
                            }
                            ps.playerUsername = data.username
                            ps.score = data.score
                            ps.correctGuesses = data.correctGuesses
                            ps.incorrectGuesses = data.incorrectGuesses
                            ps.cellsCompleted = data.cellsCompleted
                            ps.joinedAt = data.joinedAt
                            ps.lastMoveAt = data.lastMoveAt
                            result.append(ps)
                        }
                        self.otherPlayers = result
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
                state.lastMoveAt = record["lastMoveAt"] as? Date
                state.customColorRawValue = record["customColorRawValue"] as? Int
                
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
    
    /// Return to the lobby after a completed game without clearing game state.
    /// The lobby view will show a "Game Complete" state with a "Leave Lobby" button.
    func returnToLobby() {
        stopSyncTimer()
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSeconds = nil
        isGameActive = false
        // Keep currentGame, currentPlayerState, acceptedPlayers, otherPlayers
        // so the lobby can display post-game results.
        // Restart lobby polling so the lobby view stays up-to-date.
        isWaitingInLobby = true
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
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSeconds = nil
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
        hasAppliedEndGameStats = false
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
