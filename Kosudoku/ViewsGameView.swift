//
//  GameView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData
import Combine

struct GameView: View {
    @Bindable var gameManager: GameManager
    @State private var selectedNumber: Int?
    @State private var isNotesMode = false
    @State private var showingChat = false
    @State private var showingCancelAlert = false
    @State private var showingCompletionAlert = false
    @State private var showingEndOverlay = false
    @State private var viewMode: ViewMode = .balanced
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
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
                            cellEffect: $gameManager.lastCellEffect
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
                        gameManager.leaveGame()
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isViewingCompleted {
                    Button {
                        gameManager.leaveGame()
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
                GameChatView(gameSession: game)
            }
        }
        .alert("Puzzle Complete!", isPresented: $showingCompletionAlert) {
            Button("Done") {
                gameManager.leaveGame()
                dismiss()
            }
        } message: {
            if let playerState = gameManager.currentPlayerState,
               let game = gameManager.currentGame {
                let timeText: String = {
                    guard let start = game.startedAt, let end = game.completedAt else { return "" }
                    let elapsed = Int(end.timeIntervalSince(start))
                    let minutes = elapsed / 60
                    let seconds = elapsed % 60
                    return "\nTime: \(String(format: "%02d:%02d", minutes, seconds))"
                }()
                Text("Final Score: \(playerState.score)\nCorrect: \(playerState.correctGuesses) | Incorrect: \(playerState.incorrectGuesses)\(timeText)")
            } else {
                Text("Congratulations!")
            }
        }
        .onChange(of: gameManager.currentGame?.status) { _, newStatus in
            if newStatus == .completed {
                showEndSequence()
            }
        }
        .onChange(of: gameManager.isGameActive) { oldValue, newValue in
            // Also trigger on isGameActive changing from true to false (game ended)
            if oldValue && !newValue && gameManager.currentGame?.status == .completed {
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
    
    /// Show the win/loss overlay, then after it finishes, show the completion alert
    private func showEndSequence() {
        guard !showingEndOverlay && !showingCompletionAlert else { return }
        withAnimation(.easeIn(duration: 0.3)) {
            showingEndOverlay = true
        }
        // Let the overlay animate for 2.5s, then dismiss it and show the alert
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingEndOverlay = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showingCompletionAlert = true
            }
        }
    }
}

// MARK: - Completed Game Results

struct CompletedGameResultsView: View {
    let game: GameSession?
    let currentPlayer: PlayerGameState?
    let otherPlayers: [PlayerGameState]
    let playerColorMap: [String: PlayerColor]
    let onDone: () -> Void
    
    private var rankedPlayers: [PlayerGameState] {
        var all = otherPlayers
        if let current = currentPlayer {
            all.append(current)
        }
        return all.sorted { $0.score > $1.score }
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
            }
            
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
                VStack(spacing: 0) {
                    ForEach(Array(rankedPlayers.enumerated()), id: \.element.id) { index, player in
                        CompletedGamePlayerRow(
                            player: player,
                            position: index + 1,
                            isCurrentUser: player.playerRecordName == currentPlayer?.playerRecordName,
                            playerColor: playerColorMap[player.playerRecordName]?.color ?? .blue
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
    }
}

struct CompletedGamePlayerRow: View {
    let player: PlayerGameState
    let position: Int
    let isCurrentUser: Bool
    let playerColor: Color
    @State private var showingProfile = false
    
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
            
            // Score
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
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isCurrentUser ? playerColor.opacity(0.05) : Color.clear)
        .sheet(isPresented: $showingProfile) {
            PlayerProfileView(ownerRecordName: player.playerRecordName)
        }
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

#Preview {
    let container = try! ModelContainer(for: GameSession.self, PlayerGameState.self, UserProfile.self)
    let context = ModelContext(container)
    
    return NavigationStack {
        GameView(gameManager: GameManager(modelContext: context))
    }
}
