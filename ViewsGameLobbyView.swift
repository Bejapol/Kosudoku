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
    
    private var isGameCompleted: Bool {
        game?.status == .completed
    }
    
    /// Whether a countdown is currently active
    private var isCountingDown: Bool {
        if let seconds = gameManager.countdownSeconds, seconds > 0 {
            return true
        }
        return false
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
        ZStack {
            VStack(spacing: 0) {
                // Header
                if let game {
                    VStack(spacing: 8) {
                        Text(game.difficulty.rawValue.capitalized)
                            .font(.title2)
                            .bold()
                        
                        if isGameCompleted {
                            Text("Game Complete!")
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .bold()
                        } else {
                            Text("Waiting for players to join...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
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
                                ownerRecordName: game.hostRecordName,
                                status: .ready,
                                isHost: true,
                                playerColor: gameManager.playerColorMap[game.hostRecordName]?.color
                            )
                            .padding(.horizontal)
                        }
                        
                        // Invited players
                        if let game {
                            ForEach(game.invitedPlayers, id: \.self) { playerRecordName in
                                let status = playerStatus(for: playerRecordName)
                                LobbyPlayerRow(
                                    name: displayName(for: playerRecordName),
                                    ownerRecordName: playerRecordName,
                                    status: status,
                                    isHost: false,
                                    playerColor: gameManager.playerColorMap[playerRecordName]?.color
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                
                // Emote bar
                EmoteBarView(
                    onEmoteTap: { emote in
                        Task {
                            await sendEmote(emote)
                        }
                    },
                    isUnlocked: cloudKitService.currentUserProfile?.hasEmotePack ?? false
                )
                
                Divider()
                
                // Bottom controls
                VStack(spacing: 12) {
                    if isGameCompleted {
                        // Post-game: show Leave Lobby button
                        Button {
                            gameManager.leaveGame()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left.circle.fill")
                                Text("Leave Lobby")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    } else if isHost {
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
                            .background(canForceStart && !isCountingDown ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canForceStart || isCountingDown)
                        
                        Button {
                            showingCancelAlert = true
                        } label: {
                            Text("Cancel Game")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .disabled(isCountingDown)
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
                        .disabled(isCountingDown)
                    }
                }
                .padding()
            }
            
            // Countdown overlay
            if let seconds = gameManager.countdownSeconds, seconds > 0 {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                Text("\(seconds)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10)
                    .transition(.scale.combined(with: .opacity))
                    .id(seconds) // Force new view for animation
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: seconds)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gameManager.countdownSeconds)
        .navigationTitle("Game Lobby")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !isCountingDown && !isGameCompleted {
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
            // Only auto-dismiss on abandoned (not completed — we stay in lobby)
            if status == .abandoned {
                dismiss()
            }
        }
        .onChange(of: showingGameView) { _, showing in
            // When returning from GameView after game completes,
            // stay in the lobby (don't dismiss)
            if !showing {
                let status = gameManager.currentGame?.status
                if status == .abandoned {
                    dismiss()
                }
                // If completed, stay in lobby — user will see post-game UI
            }
        }
    }
    
    // MARK: - Emotes
    
    private func sendEmote(_ emote: GameEmote) async {
        guard let senderRecordName = cloudKitService.currentUserRecordName,
              let username = cloudKitService.currentUserProfile?.username,
              let game = gameManager.currentGame,
              let gameRecordName = game.cloudKitRecordName else {
            return
        }
        
        let message = ChatMessage(
            senderRecordName: senderRecordName,
            senderUsername: username,
            content: emote.rawValue,
            messageType: .reaction,
            gameSession: game
        )
        
        do {
            try await cloudKitService.sendChatMessage(message, gameRecordName: gameRecordName)
        } catch {
            print("Error sending lobby emote: \(error)")
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
    let ownerRecordName: String
    let status: LobbyPlayerStatus
    let isHost: Bool
    let playerColor: Color?
    
    @State private var profileImageData: Data?
    @State private var cloudKitService = CloudKitService.shared
    
    /// The accent color: use the player's game color if available, otherwise fall back to status-based color
    private var accentColor: Color {
        if let playerColor { return playerColor }
        switch status {
        case .ready: return .green
        case .waiting: return .orange
        case .declined: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile photo
            ProfilePhotoView(
                imageData: profileImageData,
                displayName: name,
                size: 40
            )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(accentColor)
                    
                    if isHost {
                        Text("Host")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.2))
                            .foregroundColor(accentColor)
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
        .task {
            await loadProfilePhoto()
        }
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
    
    // MARK: - Photo Loading
    
    private static var photoCache: [String: Data] = [:]
    
    private func loadProfilePhoto() async {
        if let cached = Self.photoCache[ownerRecordName] {
            if profileImageData == nil { profileImageData = cached }
            return
        }
        
        // Current user — use local profile
        if ownerRecordName == cloudKitService.currentUserRecordName,
           let currentProfile = cloudKitService.currentUserProfile {
            profileImageData = currentProfile.avatarImageData
            if let data = currentProfile.avatarImageData {
                Self.photoCache[ownerRecordName] = data
            }
            return
        }
        
        // Other users — fetch from CloudKit
        do {
            if let profile = try await cloudKitService.fetchUserProfileByOwner(ownerRecordName: ownerRecordName) {
                profileImageData = profile.avatarImageData
                if let data = profile.avatarImageData {
                    Self.photoCache[ownerRecordName] = data
                }
            }
        } catch {
            print("Failed to load profile photo for \(name): \(error)")
        }
    }
}
