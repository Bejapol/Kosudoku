//
//  HomeView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var gameManager: GameManager?
    @State private var showingNewGameSheet = false
    @State private var showingGameView = false
    @State private var showingLobbyView = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingProfileSetup = false
    @State private var cloudKitService = CloudKitService.shared
    @Query private var gameSessions: [GameSession]
    @Query private var friendships: [Friendship]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stylized logo with speed streaks
                    KosudokuLogo()
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Sign-in status banner
                        if !cloudKitService.isAuthenticated {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Not Signed In")
                                        .font(.headline)
                                    Text("Sign in to iCloud to play")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else if cloudKitService.currentUserProfile == nil {
                            Button {
                                showingProfileSetup = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Profile Required")
                                            .font(.headline)
                                        Text("Tap to create your player profile")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button {
                            // Check authentication and profile before showing sheet
                            if !cloudKitService.isAuthenticated {
                                errorMessage = "Please sign in with iCloud to play.\n\nGo to Settings > [Your Name] > iCloud and make sure you're signed in."
                                showingError = true
                            } else if cloudKitService.currentUserProfile == nil {
                                errorMessage = "Please create your player profile first."
                                showingError = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingProfileSetup = true
                                }
                            } else {
                                showingNewGameSheet = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.title)
                                Text("Start New Game")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        .opacity((cloudKitService.isAuthenticated && cloudKitService.currentUserProfile != nil) ? 1.0 : 0.5)
                    }
                    
                    // Daily Engagement Section
                    if let profile = cloudKitService.currentUserProfile {
                        DailyChallengesView(profile: profile)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Your Lobbies Section (games you host that are waiting)
                    if !hostedWaitingGames.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Your Lobbies")
                                    .font(.title2)
                                    .bold()
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                            }
                            .padding(.horizontal)
                            
                            ForEach(hostedWaitingGames) { game in
                                LobbyCard(session: game) {
                                    Task {
                                        await rejoinLobby(game)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                            .padding(.horizontal)
                    }
                    
                    // Waiting Games Section (Game Invitations)
                    if !waitingGames.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Game Invitations")
                                    .font(.title2)
                                    .bold()
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                            .padding(.horizontal)
                            
                            ForEach(waitingGames) { game in
                                GameInvitationCard(
                                    session: game,
                                    onAccept: {
                                        Task {
                                            await acceptInvitation(game)
                                        }
                                    },
                                    onDecline: {
                                        Task {
                                            await declineInvitation(game)
                                        }
                                    }
                                )
                            }
                        }
                        
                        Divider()
                            .padding(.horizontal)
                    }
                    
                    // Active Games Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Games")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        if activeGames.isEmpty {
                            Text("No active games")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(activeGames) { game in
                                GameSessionCard(session: game) {
                                    Task {
                                        await rejoinGame(game)
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Recent Games Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Games")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        if completedGames.isEmpty {
                            Text("No completed games")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(completedGames.prefix(5)) { game in
                                CompletedGameCard(session: game) {
                                    viewCompletedGame(game)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewGameSheet) {
                NewGameView { manager, isMultiplayer in
                    gameManager = manager
                    if isMultiplayer {
                        showingLobbyView = true
                    } else {
                        showingGameView = true
                    }
                }
            }
            .sheet(isPresented: $showingProfileSetup) {
                ProfileSetupView()
            }
            .navigationDestination(isPresented: $showingGameView) {
                if let manager = gameManager {
                    GameView(gameManager: manager)
                }
            }
            .navigationDestination(isPresented: $showingLobbyView) {
                if let manager = gameManager {
                    GameLobbyView(gameManager: manager, friendships: friendships)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    errorMessage = nil
                }
                if errorMessage?.contains("profile") == true && cloudKitService.isAuthenticated {
                    Button("Create Profile") {
                        errorMessage = nil
                        showingProfileSetup = true
                    }
                }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .onAppear {
            setupGameManager()
        }
        .task {
            await syncInvitedGames()
            // Initialize daily engagement
            if let profile = cloudKitService.currentUserProfile {
                let engagement = EngagementManager.shared
                engagement.checkDailyLogin(profile: profile)
                engagement.generateDailyChallenges(profile: profile)
                engagement.generateWeeklyChallenge(profile: profile)
                // Save updated profile to CloudKit
                try? await cloudKitService.saveUserProfile(profile)
            }
        }
        .refreshable {
            await syncInvitedGames()
        }
    }
    
    private var activeGames: [GameSession] {
        let currentUser = cloudKitService.currentUserRecordName ?? ""
        return gameSessions.filter { game in
            game.status == .active &&
            (game.hostRecordName == currentUser || game.invitedPlayers.contains(currentUser))
        }
    }
    
    /// Games where the current user is invited and the game is still waiting to start
    private var waitingGames: [GameSession] {
        let currentUser = cloudKitService.currentUserRecordName ?? ""
        return gameSessions.filter { game in
            game.status == .waiting &&
            game.hostRecordName != currentUser &&
            game.invitedPlayers.contains(currentUser) &&
            !game.declinedPlayers.contains(currentUser)
        }
    }
    
    /// Games where the current user is the host and the game is still waiting
    private var hostedWaitingGames: [GameSession] {
        let currentUser = cloudKitService.currentUserRecordName ?? ""
        return gameSessions.filter { game in
            game.status == .waiting &&
            game.hostRecordName == currentUser &&
            !game.invitedPlayers.isEmpty
        }
    }
    
    private var completedGames: [GameSession] {
        gameSessions.filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
    }
    
    private func setupGameManager() {
        if gameManager == nil {
            gameManager = GameManager(modelContext: modelContext)
        }
    }
    
    /// Fetch games the current user is invited to from CloudKit and insert them locally
    private func syncInvitedGames() async {
        guard cloudKitService.isAuthenticated else { return }
        
        do {
            let records = try await cloudKitService.fetchInvitedGameSessions()
            
            // Get existing local game CloudKit record names for deduplication
            let existingRecordNames = Set(gameSessions.compactMap { $0.cloudKitRecordName })
            
            for record in records {
                let recordName = record.recordID.recordName
                
                // Skip if we already have this game locally
                if existingRecordNames.contains(recordName) {
                    continue
                }
                
                guard let hostRecordName = record["hostRecordName"] as? String,
                      let difficultyRaw = record["difficulty"] as? String,
                      let difficulty = DifficultyLevel(rawValue: difficultyRaw),
                      let puzzleData = record["puzzleData"] as? String,
                      let solutionData = record["solutionData"] as? String else {
                    continue
                }
                
                let session = GameSession(
                    hostRecordName: hostRecordName,
                    difficulty: difficulty,
                    puzzleData: puzzleData,
                    solutionData: solutionData,
                    invitedPlayers: (record["invitedPlayers"] as? [String]) ?? []
                )
                session.cloudKitRecordName = recordName
                session.createdAt = (record["createdAt"] as? Date) ?? Date()
                session.declinedPlayers = (record["declinedPlayers"] as? [String]) ?? []
                
                if let statusRaw = record["status"] as? String,
                   let status = GameStatus(rawValue: statusRaw) {
                    session.status = status
                }
                if let startedAt = record["startedAt"] as? Date {
                    session.startedAt = startedAt
                }
                
                modelContext.insert(session)
                print("📥 Synced invited game: \(recordName)")
            }
            
            try? modelContext.save()
        } catch {
            print("⚠️ Failed to sync invited games: \(error.localizedDescription)")
        }
    }
    
    private func startQuickGame() async {
        // Check if authenticated
        if !cloudKitService.isAuthenticated {
            errorMessage = "Please sign in with iCloud to play.\n\nGo to Settings > [Your Name] > iCloud and make sure you're signed in."
            showingError = true
            return
        }
        
        // Check if profile exists
        if cloudKitService.currentUserProfile == nil {
            errorMessage = "Please create your player profile first."
            showingError = true
            // Show profile setup after dismissing the error
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingProfileSetup = true
            }
            return
        }
        
        guard let manager = gameManager else {
            errorMessage = "Game manager not initialized"
            showingError = true
            return
        }
        
        do {
            print("🎮 Creating game...")
            try await manager.createGame(difficulty: .medium)
            print("🎮 Starting game...")
            try await manager.startGame()
            print("🎮 Game started successfully")
            showingGameView = true
        } catch {
            print("❌ Error starting game: \(error)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func viewCompletedGame(_ session: GameSession) {
        guard let manager = gameManager else {
            errorMessage = "Game manager not initialized"
            showingError = true
            return
        }
        
        Task {
            await manager.viewCompletedGame(session)
            showingGameView = true
        }
    }
    
    private func rejoinGame(_ session: GameSession) async {
        guard let manager = gameManager else {
            errorMessage = "Game manager not initialized"
            showingError = true
            return
        }
        
        do {
            print("🎮 Rejoining game...")
            try await manager.joinGame(session)
            print("🎮 Successfully rejoined game")
            if session.status == .waiting {
                showingLobbyView = true
            } else {
                showingGameView = true
            }
        } catch {
            print("❌ Error joining game: \(error)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func rejoinLobby(_ session: GameSession) async {
        guard let manager = gameManager else {
            errorMessage = "Game manager not initialized"
            showingError = true
            return
        }
        
        do {
            print("🎮 Rejoining lobby...")
            try await manager.joinGame(session)
            print("🎮 Successfully rejoined lobby")
            showingLobbyView = true
        } catch {
            print("❌ Error rejoining lobby: \(error)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func acceptInvitation(_ session: GameSession) async {
        guard let manager = gameManager else {
            errorMessage = "Game manager not initialized"
            showingError = true
            return
        }
        
        do {
            print("🎮 Accepting game invitation...")
            try await manager.joinGame(session)
            print("🎮 Accepted invitation, entering lobby")
            showingLobbyView = true
        } catch {
            print("❌ Error accepting invitation: \(error)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func declineInvitation(_ session: GameSession) async {
        guard let manager = gameManager else {
            errorMessage = "Game manager not initialized"
            showingError = true
            return
        }
        
        do {
            print("🎮 Declining game invitation...")
            try await manager.declineGame(session)
            print("🎮 Declined invitation")
        } catch {
            print("❌ Error declining invitation: \(error)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct GameInvitationCard: View {
    let session: GameSession
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @State private var hostInviteTheme: GameInviteTheme = .classic
    @State private var cloudKitService = CloudKitService.shared
    
    private var themeColors: (primary: Color, secondary: Color) {
        switch hostInviteTheme {
        case .classic: return (.orange, .orange)
        case .royal: return (.purple, .indigo)
        case .neon: return (.green, .cyan)
        case .tropical: return (Color(red: 1.0, green: 0.6, blue: 0.0), Color(red: 1.0, green: 0.3, blue: 0.4))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: hostInviteTheme.icon)
                    .foregroundColor(themeColors.primary)
                Text(session.difficulty.rawValue.capitalized)
                    .font(.headline)
                Spacer()
                Text("Invitation")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeColors.primary.opacity(0.2))
                    .foregroundColor(themeColors.primary)
                    .cornerRadius(4)
            }
            
            Text("Created: \(session.createdAt, format: .relative(presentation: .named))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button {
                    onAccept()
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Accept")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button {
                    onDecline()
                } label: {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Decline")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [themeColors.primary.opacity(0.1), themeColors.secondary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColors.primary.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
        .padding(.horizontal)
        .task {
            await loadHostTheme()
        }
    }
    
    private func loadHostTheme() async {
        do {
            if let hostProfile = try await cloudKitService.fetchUserProfileByOwner(ownerRecordName: session.hostRecordName) {
                hostInviteTheme = hostProfile.activeGameInviteTheme
            }
        } catch {
            // Fall back to classic theme
        }
    }
}

struct LobbyCard: View {
    let session: GameSession
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.blue)
                    Text(session.difficulty.rawValue.capitalized)
                        .font(.headline)
                    Spacer()
                    Text("Lobby")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                Text("Waiting for \(session.invitedPlayers.count) player\(session.invitedPlayers.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Created: \(session.createdAt, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

struct GameSessionCard: View {
    let session: GameSession
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundColor(.blue)
                    Text(session.difficulty.rawValue.capitalized)
                        .font(.headline)
                    Spacer()
                    Text(session.status.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(4)
                }
                
                if let startedAt = session.startedAt {
                    Text("Started: \(startedAt, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
    
    private var statusColor: Color {
        switch session.status {
        case .waiting:
            return .orange
        case .active:
            return .green
        case .completed:
            return .blue
        case .abandoned:
            return .red
        }
    }
}

struct CompletedGameCard: View {
    let session: GameSession
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(session.difficulty.rawValue.capitalized)
                        .font(.headline)
                    Spacer()
                    if let completedAt = session.completedAt {
                        Text(completedAt, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let startedAt = session.startedAt, let completedAt = session.completedAt {
                    let elapsed = Int(completedAt.timeIntervalSince(startedAt))
                    let minutes = elapsed / 60
                    let seconds = elapsed % 60
                    Text("Time: \(String(format: "%02d:%02d", minutes, seconds))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stylized Logo

struct KosudokuLogo: View {
    var body: some View {
        ZStack {
            // Speed streaks behind the text
            SpeedStreaks()
            
            // Main title
            Text("KOSUDOKU")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .blue.opacity(0.3), radius: 4, x: 2, y: 2)
        }
        .padding(.vertical, 4)
    }
}

struct SpeedStreaks: View {
    var body: some View {
        Canvas { context, size in
            let centerY = size.height / 2
            
            // Define streak configurations: (yOffset, width, opacity, thickness)
            let streaks: [(CGFloat, CGFloat, Double, CGFloat)] = [
                (-18, 60, 0.35, 3),
                (-10, 80, 0.25, 2.5),
                (-3, 45, 0.3, 2),
                (5, 70, 0.2, 2.5),
                (12, 55, 0.3, 3),
                (20, 40, 0.25, 2),
            ]
            
            for (yOffset, width, opacity, thickness) in streaks {
                let y = centerY + yOffset
                let startX: CGFloat = 12
                
                var path = Path()
                path.move(to: CGPoint(x: startX, y: y))
                path.addLine(to: CGPoint(x: startX + width, y: y))
                
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            .cyan.opacity(0),
                            .cyan.opacity(opacity),
                            .blue.opacity(opacity * 0.5),
                            .blue.opacity(0)
                        ]),
                        startPoint: CGPoint(x: startX, y: y),
                        endPoint: CGPoint(x: startX + width, y: y)
                    ),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
            }
            
            // Right-side streaks (trailing the text)
            let rightStreaks: [(CGFloat, CGFloat, Double, CGFloat)] = [
                (-15, 50, 0.3, 2.5),
                (-6, 65, 0.2, 2),
                (2, 40, 0.35, 3),
                (10, 55, 0.25, 2),
                (18, 35, 0.3, 2.5),
            ]
            
            for (yOffset, width, opacity, thickness) in rightStreaks {
                let y = centerY + yOffset
                let startX = size.width - 12 - width
                
                var path = Path()
                path.move(to: CGPoint(x: startX, y: y))
                path.addLine(to: CGPoint(x: startX + width, y: y))
                
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            .blue.opacity(0),
                            .blue.opacity(opacity * 0.5),
                            .cyan.opacity(opacity),
                            .cyan.opacity(0)
                        ]),
                        startPoint: CGPoint(x: startX, y: y),
                        endPoint: CGPoint(x: startX + width, y: y)
                    ),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
            }
        }
        .frame(height: 60)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: GameSession.self, inMemory: true)
}
