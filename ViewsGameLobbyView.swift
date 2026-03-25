//
//  GameLobbyView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/25/26.
//

import SwiftUI
import SwiftData

struct GameLobbyView: View {
    @Bindable var gameManager: GameManager
    let friendships: [Friendship]
    @Environment(\.dismiss) private var dismiss
    @State private var showingCancelAlert = false
    @State private var showingGameView = false
    
    private let cloudKitService = CloudKitService.shared
    
    private var isHost: Bool {
        guard let game = gameManager.currentGame else { return false }
        return game.hostRecordName == cloudKitService.currentUserRecordName
    }
    
    private var game: GameSession? {
        gameManager.currentGame
    }
    
    /// Number of accepted players (those with PlayerGameState records)
    private var acceptedCount: Int {
        gameManager.acceptedPlayers.count
    }
    
    /// Whether the host can force-start (at least 2 players accepted)
    private var canForceStart: Bool {
        acceptedCount >= 2
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let game {
                VStack(spacing: 8) {
                    Text(game.difficulty.rawValue.capitalized)
                        .font(.title2)
                        .bold()
                    
                    Text("Waiting for players to join...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            
            Divider()
            
            // Player list
            ScrollView {
                VStack(spacing: 12) {
                    Text("Players")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    // Host (always shown first)
                    if let game {
                        LobbyPlayerRow(
                            name: hostDisplayName(game: game),
                            status: .ready,
                            isHost: true
                        )
                        .padding(.horizontal)
                    }
                    
                    // Invited players
                    if let game {
                        ForEach(game.invitedPlayers, id: \.self) { playerRecordName in
                            let status = playerStatus(for: playerRecordName)
                            LobbyPlayerRow(
                                name: displayName(for: playerRecordName),
                                status: status,
                                isHost: false
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            
            Divider()
            
            // Bottom controls
            VStack(spacing: 12) {
                if isHost {
                    Button {
                        Task {
                            try? await gameManager.forceStartGame()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Game Now")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canForceStart ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canForceStart)
                    
                    Button {
                        showingCancelAlert = true
                    } label: {
                        Text("Cancel Game")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Waiting for host to start...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        gameManager.leaveGame()
                        dismiss()
                    } label: {
                        Text("Leave Lobby")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Game Lobby")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    gameManager.leaveGame()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .alert("Cancel Game?", isPresented: $showingCancelAlert) {
            Button("Cancel Game", role: .destructive) {
                Task {
                    try? await gameManager.cancelGame()
                    dismiss()
                }
            }
            Button("Keep Waiting", role: .cancel) {}
        } message: {
            Text("This will cancel the game for all players.")
        }
        .navigationDestination(isPresented: $showingGameView) {
            GameView(gameManager: gameManager)
        }
        .onChange(of: gameManager.isGameActive) { _, isActive in
            if isActive {
                showingGameView = true
            }
        }
        .onChange(of: gameManager.currentGame?.status) { _, status in
            if status == .abandoned {
                dismiss()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func hostDisplayName(game: GameSession) -> String {
        if game.hostRecordName == cloudKitService.currentUserRecordName {
            return cloudKitService.currentUserProfile?.displayName ?? "You"
        }
        return displayName(for: game.hostRecordName)
    }
    
    private func displayName(for recordName: String) -> String {
        if recordName == cloudKitService.currentUserRecordName {
            return cloudKitService.currentUserProfile?.displayName ?? "You"
        }
        
        let currentUser = cloudKitService.currentUserRecordName ?? ""
        // Look up in friendships
        if let friendship = friendships.first(where: {
            ($0.userRecordName == currentUser && $0.friendRecordName == recordName) ||
            ($0.friendRecordName == currentUser && $0.userRecordName == recordName)
        }) {
            return friendship.friendDisplayName
        }
        
        // Look up in accepted players
        if let player = gameManager.acceptedPlayers.first(where: { $0.playerRecordName == recordName }) {
            return player.playerUsername
        }
        
        return "Unknown Player"
    }
    
    private func playerStatus(for recordName: String) -> LobbyPlayerStatus {
        // Check if declined
        if let game, game.declinedPlayers.contains(recordName) {
            return .declined
        }
        
        // Check if accepted (has a PlayerGameState record)
        if gameManager.acceptedPlayers.contains(where: { $0.playerRecordName == recordName }) {
            return .ready
        }
        
        return .waiting
    }
}

// MARK: - Player Status

enum LobbyPlayerStatus {
    case ready
    case waiting
    case declined
}

// MARK: - Player Row

struct LobbyPlayerRow: View {
    let name: String
    let status: LobbyPlayerStatus
    let isHost: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Player avatar placeholder
            Circle()
                .fill(avatarColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(avatarColor)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if isHost {
                        Text("Host")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            // Status icon
            statusIcon
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var statusText: String {
        switch status {
        case .ready: return "Ready"
        case .waiting: return "Waiting..."
        case .declined: return "Declined"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .ready: return .green
        case .waiting: return .orange
        case .declined: return .red
        }
    }
    
    private var avatarColor: Color {
        switch status {
        case .ready: return .green
        case .waiting: return .orange
        case .declined: return .gray
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        case .waiting:
            ProgressView()
        case .declined:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.title3)
        }
    }
}
