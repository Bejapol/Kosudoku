//
//  NewGameView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct NewGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDifficulty: DifficultyLevel = .medium
    @State private var selectedFriends: Set<String> = []
    @State private var isCreating = false
    @State private var createdGameManager: GameManager?
    @State private var showingGameView = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @Query private var friendships: [Friendship]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Game Settings") {
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                            Text(difficulty.rawValue.capitalized).tag(difficulty)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Invite Friends") {
                    if acceptedFriends.isEmpty {
                        Text("No friends to invite")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(acceptedFriends, id: \.id) { friendship in
                            let friendRecord = otherPersonRecordName(friendship)
                            HStack {
                                Text(friendship.friendDisplayName)
                                Spacer()
                                if selectedFriends.contains(friendRecord) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleFriendSelection(friendRecord)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Create Game") {
                        Task {
                            await createGame()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isCreating)
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isCreating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .navigationDestination(isPresented: $showingGameView) {
                if let manager = createdGameManager {
                    GameView(gameManager: manager)
                }
            }
            .alert("Error Creating Game", isPresented: $showingError) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private let cloudKitService = CloudKitService.shared
    
    private var acceptedFriends: [Friendship] {
        friendships.filter { $0.status == .accepted }
    }
    
    /// Get the record name of the "other person" in a friendship
    private func otherPersonRecordName(_ friendship: Friendship) -> String {
        let currentUser = cloudKitService.currentUserRecordName ?? ""
        if friendship.userRecordName == currentUser {
            return friendship.friendRecordName
        } else {
            return friendship.userRecordName
        }
    }
    
    private func toggleFriendSelection(_ recordName: String) {
        if selectedFriends.contains(recordName) {
            selectedFriends.remove(recordName)
        } else {
            selectedFriends.insert(recordName)
        }
    }
    
    private func createGame() async {
        isCreating = true
        
        print("🎮 Creating new game with difficulty: \(selectedDifficulty)")
        print("🎮 Invited players: \(selectedFriends)")
        
        do {
            let gameManager = GameManager(modelContext: modelContext)
            
            print("🎮 Calling createGame...")
            try await gameManager.createGame(
                difficulty: selectedDifficulty,
                invitedPlayers: Array(selectedFriends)
            )
            print("✅ Game created successfully")
            
            if selectedFriends.isEmpty {
                // Solo game - start immediately
                print("🎮 Starting solo game...")
                try await gameManager.startGame()
                print("✅ Game started successfully")
            } else {
                // Multiplayer game - start immediately for the host too
                // Friends will join the already-active game
                print("🎮 Starting multiplayer game...")
                try await gameManager.startGame()
                print("✅ Multiplayer game started, waiting for friends to join")
            }
            
            // Store the game manager and show the game view
            createdGameManager = gameManager
            isCreating = false
            dismiss()
            
            // Navigate to game view after dismissing the sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingGameView = true
            }
        } catch let error as GameError {
            print("❌ GameError creating game: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showingError = true
            isCreating = false
        } catch let error as CloudKitError {
            print("❌ CloudKitError creating game: \(error.localizedDescription)")
            errorMessage = "CloudKit error: \(error.localizedDescription)\n\nMake sure you're signed into iCloud in Settings."
            showingError = true
            isCreating = false
        } catch {
            print("❌ Unknown error creating game: \(error)")
            print("❌ Error type: \(type(of: error))")
            errorMessage = "Failed to create game: \(error.localizedDescription)\n\nPlease check your iCloud connection."
            showingError = true
            isCreating = false
        }
    }
}

#Preview {
    NewGameView()
        .modelContainer(for: Friendship.self, inMemory: true)
}
