//
//  HomeView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var gameManager: GameManager?
    @State private var showingNewGameSheet = false
    @State private var showingGameView = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingProfileSetup = false
    @State private var cloudKitService = CloudKitService.shared
    @Query private var gameSessions: [GameSession]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Play Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Play")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
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
                    
                    Divider()
                        .padding(.horizontal)
                    
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
                                GameInvitationCard(session: game) {
                                    Task {
                                        await rejoinGame(game)
                                    }
                                }
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
                                CompletedGameCard(session: game)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Kosudoku")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewGameSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingNewGameSheet) {
                NewGameView()
            }
            .sheet(isPresented: $showingProfileSetup) {
                ProfileSetupView()
            }
            .navigationDestination(isPresented: $showingGameView) {
                if let manager = gameManager {
                    GameView(gameManager: manager)
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
    }
    
    private var activeGames: [GameSession] {
        gameSessions.filter { $0.status == .active }
    }
    
    private var waitingGames: [GameSession] {
        gameSessions.filter { $0.status == .waiting }
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
            showingGameView = true
        } catch {
            print("❌ Error joining game: \(error)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct GameInvitationCard: View {
    let session: GameSession
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.orange)
                    Text(session.difficulty.rawValue.capitalized)
                        .font(.headline)
                    Spacer()
                    Text("Invitation")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                Text("Tap to join this game")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Created: \(session.createdAt, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.1), Color.orange.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
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
    
    var body: some View {
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
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: GameSession.self, inMemory: true)
}
