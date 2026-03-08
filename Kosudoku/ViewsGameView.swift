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
    @State private var viewMode: ViewMode = .balanced
    @Environment(\.dismiss) private var dismiss
    
    enum ViewMode {
        case gameboard  // Large gameboard, minimal controls
        case balanced   // Default balanced view
        case controls   // Large controls, smaller gameboard
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Live Leaderboard - shows all players' scores in real-time
            if viewMode != .gameboard {
                LiveLeaderboardView(
                    currentPlayer: gameManager.currentPlayerState,
                    otherPlayers: gameManager.otherPlayers
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
                        // Maximize gameboard
                        return max(0, min(geometry.size.width, geometry.size.height) - 20)
                    case .balanced:
                        // Default size
                        return max(0, min(geometry.size.width, geometry.size.height) - 40)
                    case .controls:
                        // Smaller gameboard
                        return max(0, min(geometry.size.width, geometry.size.height) * 0.7)
                    }
                }()
                
                VStack {
                    Spacer()
                    
                    SudokuGridView(
                        board: gameManager.currentBoard ?? SudokuBoard(),
                        selectedCell: gameManager.selectedCell,
                        onCellTap: { row, col in
                            gameManager.selectedCell = (row, col)
                        }
                    )
                    .frame(width: gridSize, height: gridSize)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        // Cycle through modes or toggle
                        if viewMode == .gameboard {
                            viewMode = .balanced
                        } else {
                            viewMode = .gameboard
                        }
                    }
                }
            }
            
            if viewMode != .gameboard {
                Divider()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Number pad and controls - Collapsible
            if viewMode != .gameboard {
                VStack(spacing: 16) {
                    // Notes mode toggle
                    Toggle("Notes Mode", isOn: $isNotesMode)
                        .padding(.horizontal)
                    
                    // Number pad
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
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
                        
                        // Clear button
                        Button {
                            // Clear cell
                            if let cell = gameManager.selectedCell,
                               var board = gameManager.currentBoard,
                               !board[cell.row, cell.col].isFixed {
                                board[cell.row, cell.col].value = nil
                                gameManager.currentBoard = board
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                        
                        // Hint button (only for solo players)
                        if gameManager.isOnlyPlayer {
                            Button {
                                gameManager.giveHint()
                            } label: {
                                Image(systemName: "lightbulb.fill")
                                    .font(.title2)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .background(Color.yellow.opacity(0.3))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Tap here hint
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewMode = .controls
                        }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.caption)
                            Text("Tap gameboard to maximize")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Minimized controls - just essential number buttons
                HStack(spacing: 16) {
                    ForEach(1...9, id: \.self) { number in
                        Button {
                            if let cell = gameManager.selectedCell {
                                if isNotesMode {
                                    gameManager.toggleNote(row: cell.row, col: cell.col, note: number)
                                } else {
                                    Task {
                                        try? await gameManager.makeMove(row: cell.row, col: cell.col, value: number)
                                    }
                                }
                            }
                        } label: {
                            Text("\(number)")
                                .font(.body)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedNumber == number ? Color.blue : Color(.systemGray6))
                                .foregroundColor(selectedNumber == number ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // Only show cancel button if player is alone
                if gameManager.isOnlyPlayer {
                    Button(role: .destructive) {
                        showingCancelAlert = true
                    } label: {
                        Text("Cancel Game")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
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
                .font(.title)
                .bold()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
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
