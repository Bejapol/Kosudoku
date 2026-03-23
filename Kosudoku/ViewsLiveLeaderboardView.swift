//
//  LiveLeaderboardView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI

/// Live leaderboard showing all players' scores in real-time
struct LiveLeaderboardView: View {
    let currentPlayer: PlayerGameState?
    let otherPlayers: [PlayerGameState]
    let playerColorMap: [String: PlayerColor]
    @State private var isExpanded = false
    
    var allPlayers: [PlayerGameState] {
        var players = otherPlayers
        if let current = currentPlayer {
            players.append(current)
        }
        return players.sorted { $0.score > $1.score }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact view - just top scores
            if !isExpanded {
                CompactLeaderboardView(
                    players: Array(allPlayers.prefix(3)),
                    currentPlayerRecordName: currentPlayer?.playerRecordName,
                    playerColorMap: playerColorMap
                )
                .onTapGesture {
                    withAnimation {
                        isExpanded = true
                    }
                }
            } else {
                // Expanded view - all players
                ExpandedLeaderboardView(
                    players: allPlayers,
                    currentPlayerRecordName: currentPlayer?.playerRecordName,
                    playerColorMap: playerColorMap
                )
                .onTapGesture {
                    withAnimation {
                        isExpanded = false
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct CompactLeaderboardView: View {
    let players: [PlayerGameState]
    let currentPlayerRecordName: String?
    let playerColorMap: [String: PlayerColor]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                let playerColor = playerColorMap[player.playerRecordName]?.color ?? .blue
                let isCurrentUser = player.playerRecordName == currentPlayerRecordName
                
                VStack(spacing: 4) {
                    // Position badge
                    PositionBadge(position: index + 1)
                    
                    // Player name
                    Text(player.playerUsername)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(isCurrentUser ? playerColor : .primary)
                        .bold(isCurrentUser)
                    
                    // Score with player color outline
                    Text("\(player.score)")
                        .font(.headline)
                        .foregroundColor(playerColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(playerColor, lineWidth: 1.5)
                        )
                    
                    // Stats
                    Text("\u{2713}\(player.correctGuesses) \u{2717}\(player.incorrectGuesses)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isCurrentUser ? playerColor.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
        }
        .padding(8)
    }
}

struct ExpandedLeaderboardView: View {
    let players: [PlayerGameState]
    let currentPlayerRecordName: String?
    let playerColorMap: [String: PlayerColor]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Live Leaderboard")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            
            Divider()
            
            // Player list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        LeaderboardRowView(
                            player: player,
                            position: index + 1,
                            isCurrentUser: player.playerRecordName == currentPlayerRecordName,
                            playerColor: playerColorMap[player.playerRecordName]?.color ?? .blue
                        )
                        
                        if index < players.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }
}

struct LeaderboardRowView: View {
    let player: PlayerGameState
    let position: Int
    let isCurrentUser: Bool
    let playerColor: Color
    @State private var profileImageData: Data?
    @State private var cloudKitService = CloudKitService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Position
            PositionBadge(position: position)
                .frame(width: 40)
            
            // Profile photo
            ProfilePhotoView(
                imageData: profileImageData,
                displayName: player.playerUsername,
                size: 36
            )
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                Text(player.playerUsername)
                    .font(.subheadline)
                    .bold(isCurrentUser)
                    .foregroundColor(isCurrentUser ? playerColor : .primary)
                
                HStack(spacing: 12) {
                    Label("\(player.correctGuesses)", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Label("\(player.incorrectGuesses)", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("\(player.cellsCompleted.count) cells")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Score with player color outline
            VStack(alignment: .trailing, spacing: 2) {
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
                
                Text("points")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(isCurrentUser ? playerColor.opacity(0.05) : Color.clear)
        .task {
            await loadProfilePhoto()
        }
    }
    
    // Fetch profile photo from CloudKit
    private func loadProfilePhoto() async {
        // If it's the current user, use their local profile
        if isCurrentUser, let currentProfile = cloudKitService.currentUserProfile {
            profileImageData = currentProfile.avatarImageData
            return
        }
        
        // For other users, fetch from CloudKit by record name
        do {
            if let profile = try await cloudKitService.fetchUserProfileObject(recordName: player.playerRecordName) {
                profileImageData = profile.avatarImageData
            }
        } catch {
            print("Failed to load profile photo for \(player.playerUsername): \(error)")
        }
    }
}

struct PositionBadge: View {
    let position: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(badgeColor.gradient)
                .frame(width: 32, height: 32)
            
            if position <= 3 {
                Image(systemName: medalIcon)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            } else {
                Text("\(position)")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
            }
        }
    }
    
    private var badgeColor: Color {
        switch position {
        case 1:
            return .yellow
        case 2:
            return .gray
        case 3:
            return .orange
        default:
            return .blue
        }
    }
    
    private var medalIcon: String {
        switch position {
        case 1:
            return "trophy.fill"
        case 2:
            return "medal.fill"
        case 3:
            return "medal.fill"
        default:
            return ""
        }
    }
}

#Preview("Compact") {
    LiveLeaderboardView(
        currentPlayer: PlayerGameState(
            playerRecordName: "player1",
            playerUsername: "alice",
            gameSession: GameSession(hostRecordName: "host", difficulty: .medium, puzzleData: "{}", solutionData: "{}")
        ),
        otherPlayers: [
            PlayerGameState(
                playerRecordName: "player2",
                playerUsername: "bob",
                gameSession: GameSession(hostRecordName: "host", difficulty: .medium, puzzleData: "{}", solutionData: "{}")
            ),
            PlayerGameState(
                playerRecordName: "player3",
                playerUsername: "charlie",
                gameSession: GameSession(hostRecordName: "host", difficulty: .medium, puzzleData: "{}", solutionData: "{}")
            )
        ],
        playerColorMap: [
            "player1": .coral,
            "player2": .teal,
            "player3": .amber
        ]
    )
    .padding()
}

#Preview("Expanded") {
    LiveLeaderboardView(
        currentPlayer: PlayerGameState(
            playerRecordName: "player1",
            playerUsername: "alice",
            gameSession: GameSession(hostRecordName: "host", difficulty: .medium, puzzleData: "{}", solutionData: "{}")
        ),
        otherPlayers: [
            PlayerGameState(
                playerRecordName: "player2",
                playerUsername: "bob",
                gameSession: GameSession(hostRecordName: "host", difficulty: .medium, puzzleData: "{}", solutionData: "{}")
            )
        ],
        playerColorMap: [
            "player1": .coral,
            "player2": .teal
        ]
    )
    .padding()
}
