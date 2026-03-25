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
    var difficulty: DifficultyLevel = .medium
    @State private var isExpanded = false
    @State private var showScoringInfo = false
    
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
                HStack(spacing: 0) {
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
                    
                    // Scoring info button
                    Button {
                        showScoringInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.trailing, 8)
                }
            } else {
                // Expanded view - all players
                ExpandedLeaderboardView(
                    players: allPlayers,
                    currentPlayerRecordName: currentPlayer?.playerRecordName,
                    playerColorMap: playerColorMap,
                    onInfoTap: { showScoringInfo = true }
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
        .sheet(isPresented: $showScoringInfo) {
            ScoringInfoView(difficulty: difficulty)
        }
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
    var onInfoTap: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Live Leaderboard")
                    .font(.headline)
                Spacer()
                
                if let onInfoTap {
                    Button {
                        onInfoTap()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
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
    @State private var showingProfile = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Position
            PositionBadge(position: position)
                .frame(width: 40)
            
            // Profile photo — tappable
            ProfilePhotoView(
                imageData: profileImageData,
                displayName: player.playerUsername,
                size: 36
            )
            .onTapGesture { showingProfile = true }
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                Text(player.playerUsername)
                    .font(.subheadline)
                    .bold(isCurrentUser)
                    .foregroundColor(isCurrentUser ? playerColor : .primary)
                    .onTapGesture { showingProfile = true }
                
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
        .sheet(isPresented: $showingProfile) {
            PlayerProfileView(ownerRecordName: player.playerRecordName)
        }
    }
    
    // Cache profile photos to avoid refetching on every sync cycle
    private static var photoCache: [String: Data] = [:]
    
    // Fetch profile photo from CloudKit
    private func loadProfilePhoto() async {
        // Check cache first
        if let cached = Self.photoCache[player.playerRecordName] {
            if profileImageData == nil { profileImageData = cached }
            return
        }
        
        // If it's the current user, use their local profile
        if isCurrentUser, let currentProfile = cloudKitService.currentUserProfile {
            profileImageData = currentProfile.avatarImageData
            if let data = currentProfile.avatarImageData {
                Self.photoCache[player.playerRecordName] = data
            }
            return
        }
        
        // For other users, look up by ownerRecordName (the iCloud user record name)
        do {
            if let profile = try await cloudKitService.fetchUserProfileByOwner(ownerRecordName: player.playerRecordName) {
                profileImageData = profile.avatarImageData
                if let data = profile.avatarImageData {
                    Self.photoCache[player.playerRecordName] = data
                }
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

// MARK: - Scoring Info

struct ScoringInfoView: View {
    let difficulty: DifficultyLevel
    @Environment(\.dismiss) private var dismiss
    
    private var pointsPerCorrect: Int {
        ScoringSystem.pointsForCorrectGuess(difficulty: difficulty)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Per Move") {
                    HStack {
                        Label("Correct guess", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Text("+\(pointsPerCorrect) pts")
                            .bold()
                    }
                    HStack {
                        Label("Incorrect guess", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(ScoringSystem.pointsForIncorrectGuess()) pts")
                            .bold()
                    }
                }
                
                Section("Difficulty Multiplier") {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        HStack {
                            Text(level.rawValue.capitalized)
                            if level == difficulty {
                                Text("(current)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(ScoringSystem.difficultyMultiplier(for: level), specifier: "%.1f")x")
                                .bold()
                                .foregroundColor(level == difficulty ? .primary : .secondary)
                        }
                    }
                }
                
                Section("Speed Bonus (end of game)") {
                    HStack {
                        Label("< 10 sec / cell", systemImage: "hare.fill")
                        Spacer()
                        Text("+5 pts/cell")
                            .bold()
                    }
                    HStack {
                        Label("10–20 sec / cell", systemImage: "figure.walk")
                        Spacer()
                        Text("+2 pts/cell")
                            .bold()
                    }
                    HStack {
                        Label("> 20 sec / cell", systemImage: "tortoise.fill")
                        Spacer()
                        Text("+0")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Finish Bonus") {
                    HStack {
                        Label("1st place", systemImage: "trophy.fill")
                            .foregroundColor(.yellow)
                        Spacer()
                        Text("+\(ScoringSystem.firstPlaceBonus) pts")
                            .bold()
                    }
                    HStack {
                        Label("2nd place", systemImage: "medal.fill")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("+\(ScoringSystem.secondPlaceBonus) pts")
                            .bold()
                    }
                    HStack {
                        Label("3rd place", systemImage: "medal.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Text("+\(ScoringSystem.thirdPlaceBonus) pts")
                            .bold()
                    }
                }
                
                Section {
                    Text("Your final score is the sum of all correct-guess points, minus incorrect-guess penalties, plus any speed and finish bonuses. The minimum score is 0.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Scoring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
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
