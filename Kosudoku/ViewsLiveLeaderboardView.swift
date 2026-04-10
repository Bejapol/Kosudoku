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
            ForEach(Array(players.enumerated()), id: \.element.playerRecordName) { index, player in
                let playerColor = playerColorMap[player.playerRecordName]?.color ?? .blue
                let isCurrentUser = player.playerRecordName == currentPlayerRecordName
                
                VStack(spacing: 4) {
                    // Position badge
                    PositionBadge(position: index + 1)
                    
                    // Player name
                    HStack(spacing: 3) {
                        OnlineStatusIndicator(ownerRecordName: player.playerRecordName, size: 6)
                        Text(player.playerUsername)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(isCurrentUser ? playerColor : .primary)
                            .bold(isCurrentUser)
                    }
                    
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
                    ForEach(Array(players.enumerated()), id: \.element.playerRecordName) { index, player in
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
    @State private var titleBadge: TitleBadge?
    @State private var profileFrame: ProfileFrame?
    @State private var rankTier: RankTier?
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
                size: 36,
                profileFrame: profileFrame
            )
            .overlay(alignment: .bottomTrailing) {
                OnlineStatusIndicator(ownerRecordName: player.playerRecordName, size: 7)
            }
            .onTapGesture { showingProfile = true }
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(player.playerUsername)
                        .font(.subheadline)
                        .bold(isCurrentUser)
                        .foregroundColor(isCurrentUser ? playerColor : .primary)
                    
                    if let badge = titleBadge, badge != .none {
                        Text(badge.displayName)
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(3)
                    }
                    
                    if let tier = rankTier {
                        RankTierBadge(tier: tier, showLabel: false, size: 12)
                    }
                }
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
    private static var badgeCache: [String: TitleBadge] = [:]
    private static var frameCache: [String: ProfileFrame] = [:]
    private static var rankCache: [String: RankTier] = [:]
    
    // Fetch profile photo from CloudKit
    private func loadProfilePhoto() async {
        // Check cache first
        if let cached = Self.photoCache[player.playerRecordName] {
            if profileImageData == nil { profileImageData = cached }
        }
        if let cachedBadge = Self.badgeCache[player.playerRecordName] {
            titleBadge = cachedBadge
        }
        if let cachedFrame = Self.frameCache[player.playerRecordName] {
            profileFrame = cachedFrame
        }
        if let cachedRank = Self.rankCache[player.playerRecordName] {
            rankTier = cachedRank
        }
        if Self.photoCache[player.playerRecordName] != nil {
            return
        }
        
        // If it's the current user, use their local profile
        if isCurrentUser, let currentProfile = cloudKitService.currentUserProfile {
            profileImageData = currentProfile.avatarImageData
            titleBadge = currentProfile.activeTitleBadge
            profileFrame = currentProfile.activeProfileFrame
            rankTier = currentProfile.rankTier
            if let data = currentProfile.avatarImageData {
                Self.photoCache[player.playerRecordName] = data
            }
            Self.badgeCache[player.playerRecordName] = currentProfile.activeTitleBadge
            Self.frameCache[player.playerRecordName] = currentProfile.activeProfileFrame
            Self.rankCache[player.playerRecordName] = currentProfile.rankTier
            return
        }
        
        // For other users, look up by ownerRecordName (the iCloud user record name)
        do {
            if let profile = try await cloudKitService.fetchUserProfileByOwner(ownerRecordName: player.playerRecordName) {
                profileImageData = profile.avatarImageData
                titleBadge = profile.activeTitleBadge
                profileFrame = profile.activeProfileFrame
                rankTier = profile.rankTier
                if let data = profile.avatarImageData {
                    Self.photoCache[player.playerRecordName] = data
                }
                Self.badgeCache[player.playerRecordName] = profile.activeTitleBadge
                Self.frameCache[player.playerRecordName] = profile.activeProfileFrame
                Self.rankCache[player.playerRecordName] = profile.rankTier
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
                        Text("-\(ScoringSystem.pointsForIncorrectGuess(difficulty: difficulty)) pts")
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
                
                Section("Winner Determination") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("1. Highest score", systemImage: "trophy.fill")
                            .foregroundColor(.yellow)
                        Label("2. Fewest incorrect guesses", systemImage: "xmark.circle")
                            .foregroundColor(.secondary)
                        Label("3. Earliest last move", systemImage: "clock")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                    Text("If all tiebreakers are equal, both players win.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("XP (Experience Points)") {
                    HStack {
                        Label("Correct cell", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Text("+2 XP")
                            .bold()
                    }
                    HStack {
                        Label("Solo win", systemImage: "trophy.fill")
                            .foregroundColor(.yellow)
                        Spacer()
                        Text("+20 XP")
                            .bold()
                    }
                    HStack {
                        Label("Multiplayer win", systemImage: "trophy.fill")
                            .foregroundColor(.yellow)
                        Spacer()
                        Text("+40 XP")
                            .bold()
                    }
                    HStack {
                        Label("First game of day", systemImage: "sun.max.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Text("2x XP")
                            .bold()
                            .foregroundColor(.orange)
                    }
                    Text("XP drives your player level. Login streaks provide up to 1.5x XP multiplier.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Rank Points (RP)") {
                    HStack {
                        Label("Multiplayer win", systemImage: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Text("+25 RP")
                            .bold()
                            .foregroundColor(.green)
                    }
                    HStack {
                        Label("Multiplayer loss", systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Text("-15 RP")
                            .bold()
                            .foregroundColor(.red)
                    }
                    Text("RP determines your competitive rank tier: Bronze, Silver, Gold, Platinum, Diamond, Master. RP is only gained or lost in multiplayer games.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Quickets") {
                    HStack {
                        Label("Multiplayer Win", systemImage: "ticket.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Text("+1 quicket")
                            .bold()
                            .foregroundColor(.orange)
                    }
                    Text("Quickets are only awarded for winning multiplayer games. Solo games do not award quickets. New players start with 5 quickets.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Text("Your final score is the sum of all correct-guess points, minus incorrect-guess penalties. The minimum score is 0.")
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
