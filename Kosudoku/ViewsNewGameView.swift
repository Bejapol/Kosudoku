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
    @State private var selectedDifficulty: DifficultyLevel = .easy
    @State private var selectedFriends: Set<String> = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @Query private var friendships: [Friendship]
    
    /// Callback when a game is created. Parameters: (GameManager, isMultiplayer)
    var onGameCreated: ((GameManager, Bool) -> Void)?
    
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
                
                Section {
                    if acceptedFriends.isEmpty {
                        Text("No friends to invite")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(acceptedFriends, id: \.id) { friendship in
                            let friendRecord = otherPersonRecordName(friendship)
                            let isSelected = selectedFriends.contains(friendRecord)
                            InviteFriendRow(
                                name: friendship.friendDisplayName,
                                ownerRecordName: friendRecord,
                                isSelected: isSelected,
                                onInviteTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        toggleFriendSelection(friendRecord)
                                    }
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                } header: {
                    Text("Invite Friends")
                } footer: {
                    if !selectedFriends.isEmpty {
                        Text("\(selectedFriends.count) friend\(selectedFriends.count == 1 ? "" : "s") selected")
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
        
        let isMultiplayer = !selectedFriends.isEmpty
        
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
            
            if isMultiplayer {
                // Multiplayer game — stay in .waiting, host enters lobby
                // joinGame() in createGame() already called startLobbyPolling()
                print("🎮 Multiplayer game created, entering lobby")
            } else {
                // Solo game — start immediately
                print("🎮 Starting solo game...")
                try await gameManager.startGame()
                print("✅ Game started successfully")
            }
            
            isCreating = false
            dismiss()
            
            // Notify the parent to handle navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onGameCreated?(gameManager, isMultiplayer)
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

// MARK: - Invite Friend Row

struct InviteFriendRow: View {
    let name: String
    let ownerRecordName: String
    let isSelected: Bool
    let onInviteTap: () -> Void
    
    @State private var profileImageData: Data?
    @State private var rankTier: RankTier?
    @State private var profileFrame: ProfileFrame?
    @State private var showingProfile = false
    @State private var cloudKitService = CloudKitService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile photo with frame and online indicator
            ProfilePhotoView(
                imageData: profileImageData,
                displayName: name,
                size: 40,
                profileFrame: profileFrame
            )
            .overlay(alignment: .bottomTrailing) {
                OnlineStatusIndicator(ownerRecordName: ownerRecordName)
            }
            
            // Name and rank — tappable to show profile
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if let tier = rankTier {
                        RankTierBadge(tier: tier, showLabel: false, size: 12)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { showingProfile = true }
            
            Spacer()
            
            // Invite button
            Button {
                onInviteTap()
            } label: {
                if isSelected {
                    Label("Invited", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(16)
                } else {
                    Label("Invite", systemImage: "plus.circle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingProfile) {
            PlayerProfileView(ownerRecordName: ownerRecordName)
        }
        .task {
            await loadProfile()
        }
    }
    
    // MARK: - Profile Loading
    
    private static var photoCache: [String: Data] = [:]
    private static var rankCache: [String: RankTier] = [:]
    private static var frameCache: [String: ProfileFrame] = [:]
    
    private func loadProfile() async {
        if let cached = Self.photoCache[ownerRecordName] {
            if profileImageData == nil { profileImageData = cached }
        }
        if let cachedRank = Self.rankCache[ownerRecordName] {
            rankTier = cachedRank
        }
        if let cachedFrame = Self.frameCache[ownerRecordName] {
            profileFrame = cachedFrame
        }
        if Self.photoCache[ownerRecordName] != nil {
            return
        }
        
        // Current user — use local profile
        if ownerRecordName == cloudKitService.currentUserRecordName,
           let currentProfile = cloudKitService.currentUserProfile {
            profileImageData = currentProfile.avatarImageData
            rankTier = currentProfile.rankTier
            profileFrame = currentProfile.activeProfileFrame
            if let data = currentProfile.avatarImageData {
                Self.photoCache[ownerRecordName] = data
            }
            Self.rankCache[ownerRecordName] = currentProfile.rankTier
            Self.frameCache[ownerRecordName] = currentProfile.activeProfileFrame
            return
        }
        
        // Other users — fetch from CloudKit
        do {
            if let profile = try await cloudKitService.fetchUserProfileByOwner(ownerRecordName: ownerRecordName) {
                profileImageData = profile.avatarImageData
                rankTier = profile.rankTier
                profileFrame = profile.activeProfileFrame
                if let data = profile.avatarImageData {
                    Self.photoCache[ownerRecordName] = data
                }
                Self.rankCache[ownerRecordName] = profile.rankTier
                Self.frameCache[ownerRecordName] = profile.activeProfileFrame
            }
        } catch {
            print("Failed to load profile for \(name): \(error)")
        }
    }
}

#Preview {
    NewGameView()
        .modelContainer(for: Friendship.self, inMemory: true)
}
