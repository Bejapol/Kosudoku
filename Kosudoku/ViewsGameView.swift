//
//  GameView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData
import Combine
import CloudKit

struct GameView: View {
    @Bindable var gameManager: GameManager
    @State private var selectedNumber: Int?
    @State private var isNotesMode = false
    @State private var showingChat = false
    @State private var showingCancelAlert = false
    @State private var showingEndOverlay = false
    @State private var showingQuicketAnimation = false
    @State private var showingLevelUp = false
    @State private var showingAchievement = false
    @State private var levelUpNumber: Int?
    @State private var achievementToShow: Achievement?
    @State private var viewMode: ViewMode = .balanced
    @State private var currentEmoteEvent: EmoteEvent?
    @State private var seenEmoteIDs: Set<String> = []
    @State private var emoteTimer: Timer?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    private var cloudKitService: CloudKitService { CloudKitService.shared }
    private var engagementManager: EngagementManager { EngagementManager.shared }
    
    private var userCellTheme: CellTheme {
        cloudKitService.currentUserProfile?.activeCellTheme ?? .classic
    }
    
    private var userBoardSkin: BoardSkin {
        cloudKitService.currentUserProfile?.activeBoardSkin ?? .classic
    }
    
    enum ViewMode {
        case gameboard  // Large gameboard, minimal controls
        case balanced   // Default balanced view
        case controls   // Large controls, smaller gameboard
    }
    
    private var isViewingCompleted: Bool {
        gameManager.currentGame?.status == .completed
    }
    
    private var currentPlayerColor: Color {
        guard let recordName = gameManager.currentPlayerState?.playerRecordName else {
            return PlayerColor.coral.color
        }
        return gameManager.playerColorMap[recordName]?.color ?? PlayerColor.coral.color
    }
    
    private var cellSelections: [String: [PlayerColor]] {
        var result: [String: [PlayerColor]] = [:]
        for player in gameManager.otherPlayers {
            guard let row = player.selectedRow, let col = player.selectedCol else { continue }
            let key = "\(row)-\(col)"
            let color = gameManager.playerColorMap[player.playerRecordName] ?? .coral
            result[key, default: []].append(color)
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Live Leaderboard - shows all players' scores in real-time
            if viewMode != .gameboard && !isViewingCompleted {
                LiveLeaderboardView(
                    currentPlayer: gameManager.currentPlayerState,
                    otherPlayers: gameManager.otherPlayers,
                    playerColorMap: gameManager.playerColorMap,
                    difficulty: gameManager.currentGame?.difficulty ?? .medium
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                
                Divider()
            }
            
            // Sudoku Grid - Expandable
            GeometryReader { geometry in
                let gridSize: CGFloat = {
                    switch viewMode {
                    case .gameboard:
                        // Maximize gameboard - leave more room at top for safe area
                        return max(0, min(geometry.size.width, geometry.size.height - 40) - 20)
                    case .balanced:
                        // Default size - prioritize larger gameboard
                        return max(0, min(geometry.size.width, geometry.size.height) - 16)
                    case .controls:
                        // Smaller gameboard
                        return max(0, min(geometry.size.width, geometry.size.height) * 0.7)
                    }
                }()
                
                ZStack {
                    // Sudoku grid - centered and always interactive
                    VStack {
                        if viewMode == .gameboard {
                            Spacer()
                                .frame(height: 60)  // Extra space at top when maximized
                        } else {
                            Spacer()
                        }
                        
                        SudokuGridView(
                            board: gameManager.currentBoard ?? SudokuBoard(),
                            selectedCell: gameManager.selectedCell,
                            onCellTap: { row, col in
                                gameManager.selectedCell = (row, col)
                            },
                            currentPlayerColor: currentPlayerColor,
                            cellSelections: cellSelections,
                            colorMap: gameManager.playerColorMap,
                            cellEffect: $gameManager.lastCellEffect,
                            cellTheme: userCellTheme,
                            boardSkin: userBoardSkin
                        )
                        .frame(width: gridSize, height: gridSize)

                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    

                }
            }
            
            if viewMode != .gameboard && !isViewingCompleted {
                Divider()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Completed game summary with final standings
            if isViewingCompleted {
                CompletedGameResultsView(
                    game: gameManager.currentGame,
                    currentPlayer: gameManager.currentPlayerState,
                    otherPlayers: gameManager.otherPlayers,
                    playerColorMap: gameManager.playerColorMap,
                    onDone: {
                        gameManager.returnToLobby()
                        dismiss()
                    }
                )
            }
            // Number pad and controls - Collapsible
            else if viewMode != .gameboard {
                VStack(spacing: 8) {
                    // Notes mode toggle
                    Toggle("Notes Mode", isOn: $isNotesMode)
                        .padding(.horizontal)
                    
                    // Number pad
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(1...9, id: \.self) { number in
                            NumberButton(number: number, isSelected: selectedNumber == number) {
                                if let cell = gameManager.selectedCell {
                                    if isNotesMode {
                                        gameManager.toggleNote(row: cell.row, col: cell.col, note: number)
                                    } else {
                                        Task {
                                            try? await gameManager.makeMove(row: cell.row, col: cell.col, value: number)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Hint button (only for solo players)
                        if gameManager.isOnlyPlayer {
                            Button {
                                gameManager.giveHint()
                            } label: {
                                Image(systemName: "lightbulb.fill")
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.yellow.opacity(0.3))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Boost buttons (multiplayer)
                    if !gameManager.isOnlyPlayer {
                        boostButtonsRow
                    }
                    
                    // Maximize gameboard button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewMode = .gameboard
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                            Text("Maximize gameboard")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !isViewingCompleted {
                // Full controls in maximized gameboard mode
                VStack(spacing: 8) {
                    // Notes mode toggle
                    Toggle("Notes Mode", isOn: $isNotesMode)
                        .padding(.horizontal)
                    
                    // Number pad
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(1...9, id: \.self) { number in
                            NumberButton(number: number, isSelected: selectedNumber == number) {
                                if let cell = gameManager.selectedCell {
                                    if isNotesMode {
                                        gameManager.toggleNote(row: cell.row, col: cell.col, note: number)
                                    } else {
                                        Task {
                                            try? await gameManager.makeMove(row: cell.row, col: cell.col, value: number)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Hint button (only for solo players)
                        if gameManager.isOnlyPlayer {
                            Button {
                                gameManager.giveHint()
                            } label: {
                                Image(systemName: "lightbulb.fill")
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.yellow.opacity(0.3))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Boost buttons (multiplayer) in gameboard mode
                    if !gameManager.isOnlyPlayer {
                        boostButtonsRow
                    }
                }
                .padding(.vertical, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if showingEndOverlay, let result = gameManager.gameEndResult {
                GameEndOverlay(result: result)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if showingQuicketAnimation {
                QuicketFloatOverlay(amount: 1)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if showingLevelUp, let level = levelUpNumber {
                LevelUpOverlay(level: level)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if showingAchievement, let achievement = achievementToShow {
                AchievementUnlockOverlay(achievement: achievement)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            EmoteAnimationOverlay(emoteEvent: $currentEmoteEvent)
        }
        .onAppear { startEmotePolling() }
        .onDisappear { stopEmotePolling() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isViewingCompleted {
                    Button {
                        gameManager.returnToLobby()
                        dismiss()
                    } label: {
                        Text("Done")
                    }
                } else if gameManager.isOnlyPlayer {
                    // Only show cancel button if player is alone
                    Button(role: .destructive) {
                        showingCancelAlert = true
                    } label: {
                        Text("Cancel Game")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isViewingCompleted {
                    HStack(spacing: 16) {
                        // View mode toggle button
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                switch viewMode {
                                case .gameboard:
                                    viewMode = .balanced
                                case .balanced:
                                    viewMode = .gameboard
                                case .controls:
                                    viewMode = .balanced
                                }
                            }
                        } label: {
                            Image(systemName: viewMode == .gameboard ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        }
                        
                        Button {
                            showingChat.toggle()
                        } label: {
                            Image(systemName: "message.fill")
                        }
                    }
                }
            }
        }
        .alert("Cancel Game?", isPresented: $showingCancelAlert) {
            Button("Cancel Game", role: .destructive) {
                Task {
                    do {
                        try await gameManager.cancelGame()
                        dismiss()
                    } catch {
                        print("Error cancelling game: \(error)")
                    }
                }
            }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("You're the only player in this game. Are you sure you want to cancel it?")
        }
        .sheet(isPresented: $showingChat) {
            if let game = gameManager.currentGame {
                GameChatView(gameSession: game, onEmoteSent: { emote in
                    let username = CloudKitService.shared.currentUserProfile?.username ?? ""
                    currentEmoteEvent = EmoteEvent(emote: emote, senderUsername: username, isCurrentUser: true)
                    GameSoundManager.shared.playEmoteSound(for: emote)
                })
            }
        }
        .onChange(of: gameManager.gameEndResult) { _, newResult in
            if newResult != nil {
                showEndSequence()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameEndResultSet)) { _ in
            if gameManager.gameEndResult != nil {
                showEndSequence()
            }
        }
        .onAppear {
            // Immediately sync when the game view appears
            if !isViewingCompleted {
                gameManager.triggerSync()
            }
        }
        
        .onChange(of: scenePhase) { _, newPhase in
            // Sync immediately when returning from background
            if newPhase == .active && !isViewingCompleted {
                gameManager.triggerSync()
            }
        }
    }
    
    // MARK: - Boost Buttons
    
    private var boostButtonsRow: some View {
        HStack(spacing: 12) {
            // Hint Token
            Button {
                Task { await gameManager.useHintToken() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                    Text("Hint (\(cloudKitService.currentUserProfile?.hintTokens ?? 0))")
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(gameManager.canUseHintToken ? Color.yellow.opacity(0.3) : Color(.systemGray5))
                .foregroundColor(gameManager.canUseHintToken ? .orange : .secondary)
                .cornerRadius(8)
            }
            .disabled(!gameManager.canUseHintToken)
            
            Spacer()
            
            // Undo Shield indicator
            if !gameManager.hasUsedUndoShield, (cloudKitService.currentUserProfile?.undoShields ?? 0) > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "shield.fill")
                        .font(.caption)
                    Text("Shield")
                        .font(.caption)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private func showLevelUpOverlay(level: Int) {
        levelUpNumber = level
        withAnimation(.easeIn(duration: 0.3)) {
            showingLevelUp = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingLevelUp = false
            }
            levelUpNumber = nil
            engagementManager.recentLevelUp = nil
        }
    }
    
    private func showAchievementOverlay(achievement: Achievement) {
        achievementToShow = achievement
        withAnimation(.easeIn(duration: 0.3)) {
            showingAchievement = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingAchievement = false
            }
            achievementToShow = nil
            engagementManager.recentAchievements.removeAll()
        }
    }
    
    /// Show the win/loss overlay, then quicket animation (multiplayer wins only).
    /// The game transitions to the results screen automatically after
    /// the animations complete (GameManager sets game.status = .completed).
    // MARK: - Emote Polling
    
    private func startEmotePolling() {
        emoteTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { await fetchEmotes() }
        }
    }
    
    private func stopEmotePolling() {
        emoteTimer?.invalidate()
        emoteTimer = nil
    }
    
    private func fetchEmotes() async {
        guard let gameRecordName = gameManager.currentGame?.cloudKitRecordName else { return }
        let cloudKit = CloudKitService.shared
        
        do {
            let records = try await cloudKit.fetchChatMessages(gameRecordName: gameRecordName)
            
            for record in records {
                guard let messageTypeRaw = record["messageType"] as? String,
                      messageTypeRaw == "reaction",
                      let senderRecordName = record["senderRecordName"] as? String,
                      let senderUsername = record["senderUsername"] as? String,
                      let content = record["content"] as? String else {
                    continue
                }
                
                let timestamp = (record["timestamp"] as? Date) ?? Date()
                let stableKey = "\(senderRecordName)|\(content)|\(Int(timestamp.timeIntervalSince1970))"
                
                guard !seenEmoteIDs.contains(stableKey) else { continue }
                seenEmoteIDs.insert(stableKey)
                
                // Skip own emotes (shown locally via chat callback)
                guard senderRecordName != cloudKit.currentUserRecordName else { continue }
                
                if let emote = GameEmote(rawValue: content) {
                    await MainActor.run {
                        currentEmoteEvent = EmoteEvent(emote: emote, senderUsername: senderUsername, isCurrentUser: false)
                        GameSoundManager.shared.playEmoteSound(for: emote)
                    }
                }
            }
        } catch {
            print("Error fetching game emotes: \(error)")
        }
    }
    
    private func showEndSequence() {
        guard !showingEndOverlay else { return }
        
        let showQuicket = gameManager.gameEndResult == .won && !gameManager.isOnlyPlayer
        
        // Surface level-up/achievement rewards earned during the game
        if let profile = CloudKitService.shared.currentUserProfile {
            engagementManager.surfaceGameEndRewards(profile: profile)
        }
        let pendingLevelUp = engagementManager.recentLevelUp
        let pendingAchievements = engagementManager.recentAchievements
        
        withAnimation(.easeIn(duration: 0.3)) {
            showingEndOverlay = true
        }
        
        // Track running delay for sequential animations
        var nextDelay: Double = 2.5
        
        // Dismiss the end overlay after 2.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingEndOverlay = false
            }
        }
        
        if showQuicket {
            // Show quicket animation after a brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay + 0.3) {
                withAnimation(.easeIn(duration: 0.2)) {
                    showingQuicketAnimation = true
                }
            }
            // Dismiss quicket animation
            DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay + 2.7) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showingQuicketAnimation = false
                }
            }
            nextDelay += 3.0
        }
        
        // Level-up overlay (after quicket or after win/loss if no quicket)
        if let level = pendingLevelUp {
            let levelUpStart = nextDelay + 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + levelUpStart) {
                showLevelUpOverlay(level: level)
            }
            nextDelay = levelUpStart + 3.5 // 3.0s display + 0.5s buffer
        }
        
        // Achievement overlay (after level-up or after previous animation)
        if let achievement = pendingAchievements.first {
            let achievementStart = nextDelay + 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + achievementStart) {
                showAchievementOverlay(achievement: achievement)
            }
            nextDelay = achievementStart + 3.5
        }
        
        // Tell GameManager how long to wait before transitioning to results
        gameManager.scheduleGameCompletion(afterDelay: nextDelay + 0.5)
    }
}

// MARK: - Completed Game Results

struct CompletedGameResultsView: View {
    let game: GameSession?
    let currentPlayer: PlayerGameState?
    let otherPlayers: [PlayerGameState]
    let playerColorMap: [String: PlayerColor]
    let onDone: () -> Void
    @State private var showingScoringInfo = false
    
    private var rankedPlayers: [PlayerGameState] {
        var all = otherPlayers
        if let current = currentPlayer {
            all.append(current)
        }
        return all.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.incorrectGuesses != $1.incorrectGuesses {
                return $0.incorrectGuesses < $1.incorrectGuesses
            }
            let t0 = $0.lastMoveAt ?? .distantFuture
            let t1 = $1.lastMoveAt ?? .distantFuture
            return t0 < t1
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Puzzle Complete")
                    .font(.title3)
                    .bold()
                
                Spacer()
                
                Button {
                    showingScoringInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Game info
            if let game,
               let startedAt = game.startedAt,
               let completedAt = game.completedAt {
                let elapsed = Int(completedAt.timeIntervalSince(startedAt))
                let minutes = elapsed / 60
                let seconds = elapsed % 60
                HStack(spacing: 20) {
                    Label(game.difficulty.rawValue.capitalized, systemImage: "speedometer")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Label(String(format: "%02d:%02d", minutes, seconds), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Player standings
            if !rankedPlayers.isEmpty {
                let gameTimeElapsed: TimeInterval = {
                    guard let g = game, let s = g.startedAt, let c = g.completedAt else { return 0 }
                    return c.timeIntervalSince(s)
                }()
                
                VStack(spacing: 0) {
                    ForEach(Array(rankedPlayers.enumerated()), id: \.element.playerRecordName) { index, player in
                        CompletedGamePlayerRow(
                            player: player,
                            position: index + 1,
                            isCurrentUser: player.playerRecordName == currentPlayer?.playerRecordName,
                            playerColor: playerColorMap[player.playerRecordName]?.color ?? .blue,
                            difficulty: game?.difficulty ?? .medium,
                            timeElapsed: gameTimeElapsed
                        )
                        
                        if index < rankedPlayers.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Done button
            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .sheet(isPresented: $showingScoringInfo) {
            ScoringInfoView(difficulty: game?.difficulty ?? .medium)
        }
    }
}

struct CompletedGamePlayerRow: View {
    let player: PlayerGameState
    let position: Int
    let isCurrentUser: Bool
    let playerColor: Color
    let difficulty: DifficultyLevel
    let timeElapsed: TimeInterval
    @State private var showingProfile = false
    @State private var showingBreakdown = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Position
            PositionBadge(position: position)
                .frame(width: 32)
            
            // Player name — tappable
            VStack(alignment: .leading, spacing: 2) {
                Text(player.playerUsername)
                    .font(.subheadline)
                    .bold(isCurrentUser)
                    .foregroundColor(playerColor)
                
                HStack(spacing: 8) {
                    Label("\(player.correctGuesses)", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Label("\(player.incorrectGuesses)", systemImage: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text("\(player.cellsCompleted.count) cells")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .onTapGesture { showingProfile = true }
            
            Spacer()
            
            // Score — tappable for breakdown
            Text("\(player.score)")
                .font(.title3)
                .bold()
                .foregroundColor(playerColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(playerColor, lineWidth: 2)
                )
                .onTapGesture { showingBreakdown = true }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isCurrentUser ? playerColor.opacity(0.05) : Color.clear)
        .sheet(isPresented: $showingProfile) {
            PlayerProfileView(ownerRecordName: player.playerRecordName)
        }
        .sheet(isPresented: $showingBreakdown) {
            ScoreBreakdownView(
                player: player,
                position: position,
                difficulty: difficulty,
                timeElapsed: timeElapsed,
                playerColor: playerColor
            )
        }
    }
}

// MARK: - Score Breakdown

struct ScoreBreakdownView: View {
    let player: PlayerGameState
    let position: Int
    let difficulty: DifficultyLevel
    let timeElapsed: TimeInterval
    let playerColor: Color
    @Environment(\.dismiss) private var dismiss
    
    private var pointsPerCorrect: Int {
        ScoringSystem.pointsForCorrectGuess(difficulty: difficulty)
    }
    
    private var correctTotal: Int {
        player.correctGuesses * pointsPerCorrect
    }
    
    private var incorrectTotal: Int {
        player.incorrectGuesses * ScoringSystem.incorrectGuessPenalty
    }
    
    private var computedTotal: Int {
        player.score
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Player header
                HStack {
                    PositionBadge(position: position)
                        .frame(width: 32)
                    Text(player.playerUsername)
                        .font(.headline)
                        .foregroundColor(playerColor)
                    Spacer()
                }
                .padding()
                
                Divider()
                
                // Breakdown rows
                VStack(spacing: 0) {
                    breakdownRow(
                        label: "Correct guesses",
                        detail: "\(player.correctGuesses) × \(pointsPerCorrect) pts (\(difficulty.rawValue.capitalized))",
                        value: correctTotal,
                        isPositive: true
                    )
                    
                    Divider().padding(.leading, 16)
                    
                    breakdownRow(
                        label: "Incorrect guesses",
                        detail: "\(player.incorrectGuesses) × \(ScoringSystem.incorrectGuessPenalty) pts",
                        value: incorrectTotal > 0 ? -incorrectTotal : 0,
                        isPositive: false
                    )
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                
                // Total
                HStack {
                    Text("Total")
                        .font(.title3)
                        .bold()
                    Spacer()
                    Text("\(computedTotal)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(playerColor)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 8)
                
                Spacer()
            }
            .navigationTitle("Score Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func breakdownRow(label: String, detail: String, value: Int, isPositive: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(value > 0 ? "+\(value)" : value < 0 ? "\(value)" : "0")
                .font(.subheadline)
                .bold()
                .foregroundColor(value > 0 ? .green : value < 0 ? .red : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct GameHeaderView: View {
    let gameManager: GameManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Score: \(gameManager.currentPlayerState?.score ?? 0)")
                    .font(.headline)
                Text(gameManager.currentGame?.difficulty.rawValue.capitalized ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let startTime = gameManager.gameStartTime {
                TimeElapsedView(startTime: startTime)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(gameManager.otherPlayers.count) players")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let playerState = gameManager.currentPlayerState {
                    Text("✓ \(playerState.correctGuesses) | ✗ \(playerState.incorrectGuesses)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct TimeElapsedView: View {
    let startTime: Date
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(timeString)
            .font(.title2)
            .monospacedDigit()
            .onReceive(timer) { _ in
                currentTime = Date()
            }
    }
    
    private var timeString: String {
        let elapsed = currentTime.timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct NumberButton: View {
    let number: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

// MARK: - Game End Overlay

struct GameEndOverlay: View {
    let result: GameManager.GameEndResult
    
    @State private var scale: CGFloat = 0.1
    @State private var rotation: Double = -15
    @State private var opacity: Double = 0
    @State private var bounceOffset: CGFloat = 0
    
    private var text: String {
        switch result {
        case .won: return "YOU WON!"
        case .lost: return "YOU LOST!"
        }
    }
    
    private var colors: [Color] {
        switch result {
        case .won: return [.yellow, .orange, .yellow]
        case .lost: return [.red, .purple, .red]
        }
    }
    
    private var shadowColor: Color {
        switch result {
        case .won: return .orange
        case .lost: return .red
        }
    }
    
    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(opacity * 0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main text with cartoon styling
                Text(text)
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: shadowColor.opacity(0.8), radius: 0, x: 3, y: 3)
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                    .overlay {
                        // Stroke outline effect
                        Text(text)
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .italic()
                            .foregroundColor(.clear)
                            .overlay {
                                Text(text)
                                    .font(.system(size: 56, weight: .black, design: .rounded))
                                    .italic()
                                    .foregroundStyle(.white.opacity(0.3))
                                    .blur(radius: 2)
                            }
                    }
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                    .offset(y: bounceOffset)
            }
            .opacity(opacity)
        }
        .onAppear {
            // Play the appropriate sound effect
            switch result {
            case .won:
                GameSoundManager.shared.playWinSound()
            case .lost:
                GameSoundManager.shared.playLoseSound()
            }
            
            // Pop in with overshoot
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0)) {
                scale = 1.0
                rotation = -3
                opacity = 1.0
            }
            
            // Subtle bounce settle
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.5)) {
                rotation = 2
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.8)) {
                rotation = 0
            }
            
            // Fade out
            withAnimation(.easeIn(duration: 0.6).delay(1.8)) {
                opacity = 0
                scale = 1.15
            }
        }
    }
}

// MARK: - Quicket Overlay

struct QuicketFloatOverlay: View {
    let amount: Int
    
    @State private var scale: CGFloat = 0.1
    @State private var rotation: Double = -15
    @State private var opacity: Double = 0
    @State private var bounceOffset: CGFloat = 0
    
    private let goldColors: [Color] = [
        Color(red: 1.0, green: 0.84, blue: 0.0),
        Color(red: 0.85, green: 0.65, blue: 0.13),
        Color(red: 1.0, green: 0.84, blue: 0.0)
    ]
    
    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(opacity * 0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text("QUICKETS +\(amount)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: goldColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.8), radius: 0, x: 3, y: 3)
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                    .overlay {
                        Text("QUICKETS +\(amount)")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .italic()
                            .foregroundStyle(.white.opacity(0.3))
                            .blur(radius: 2)
                    }
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                    .offset(y: bounceOffset)
            }
            .opacity(opacity)
        }
        .onAppear {
            // Pop in with overshoot (same as GameEndOverlay)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0)) {
                scale = 1.0
                rotation = -3
                opacity = 1.0
            }
            
            // Subtle bounce settle
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.5)) {
                rotation = 2
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.8)) {
                rotation = 0
            }
            
            // Fade out
            withAnimation(.easeIn(duration: 0.6).delay(1.8)) {
                opacity = 0
                scale = 1.15
            }
        }
    }
}

// MARK: - Level Up Overlay

struct LevelUpOverlay: View {
    let level: Int
    
    @State private var scale: CGFloat = 0.1
    @State private var rotation: Double = -15
    @State private var opacity: Double = 0
    
    private let levelColors: [Color] = [.cyan, .blue, .purple]
    
    private var milestoneReward: LevelMilestone? {
        LevelMilestone.milestones.first { $0.level == level }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(opacity * 0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Text("LEVEL UP!")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: levelColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.8), radius: 0, x: 3, y: 3)
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                
                Text("Level \(level)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if let milestone = milestoneReward {
                    VStack(spacing: 4) {
                        Text("Unlocked:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        Text(milestone.rewardDescription)
                            .font(.headline)
                            .foregroundColor(.yellow)
                    }
                    .padding(.top, 4)
                }
            }
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0)) {
                scale = 1.0
                rotation = -3
                opacity = 1.0
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.5)) {
                rotation = 2
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.8)) {
                rotation = 0
            }
            withAnimation(.easeIn(duration: 0.6).delay(2.2)) {
                opacity = 0
                scale = 1.15
            }
        }
    }
}

// MARK: - Achievement Unlock Overlay

struct AchievementUnlockOverlay: View {
    let achievement: Achievement
    
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0
    @State private var iconScale: CGFloat = 0.1
    
    var body: some View {
        ZStack {
            Color.black.opacity(opacity * 0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: achievement.icon)
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .orange.opacity(0.6), radius: 10)
                    .scaleEffect(iconScale)
                
                Text("ACHIEVEMENT")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundColor(.yellow.opacity(0.8))
                
                Text(achievement.displayName)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.4).delay(0.2)) {
                iconScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.6).delay(2.2)) {
                opacity = 0
                scale = 1.1
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: GameSession.self, PlayerGameState.self, UserProfile.self)
    let context = ModelContext(container)
    
    return NavigationStack {
        GameView(gameManager: GameManager(modelContext: context))
    }
}
