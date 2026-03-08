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
                            HStack {
                                Text(friendship.friendDisplayName)
                                Spacer()
                                if selectedFriends.contains(friendship.friendRecordName) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleFriendSelection(friendship.friendRecordName)
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
        }
    }
    
    private var acceptedFriends: [Friendship] {
        friendships.filter { $0.status == .accepted }
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
        
        do {
            let gameManager = GameManager(modelContext: modelContext)
            try await gameManager.createGame(
                difficulty: selectedDifficulty,
                invitedPlayers: Array(selectedFriends)
            )
            
            // Start the game automatically
            try await gameManager.startGame()
            
            // Store the game manager and show the game view
            createdGameManager = gameManager
            isCreating = false
            dismiss()
            
            // Navigate to game view after dismissing the sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingGameView = true
            }
        } catch {
            print("Error creating game: \(error)")
            isCreating = false
        }
    }
}

#Preview {
    NewGameView()
        .modelContainer(for: Friendship.self, inMemory: true)
}
