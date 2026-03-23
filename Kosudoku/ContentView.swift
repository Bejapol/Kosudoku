//
//  ContentView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var cloudKitService = CloudKitService.shared
    @State private var showingProfileSetup = false
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query private var gameSessions: [GameSession]
    @Query private var friendships: [Friendship]
    
    private var waitingGamesCount: Int {
        gameSessions.filter { $0.status == .waiting }.count
    }
    
    private var pendingFriendRequestCount: Int {
        guard let currentUser = cloudKitService.currentUserRecordName else { return 0 }
        // Only count requests where I am the recipient (friendRecordName), not ones I sent
        return friendships.filter { $0.status == .pending && $0.friendRecordName == currentUser }.count
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
                .badge(waitingGamesCount > 0 ? waitingGamesCount : 0)
            
            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(1)
                .badge(pendingFriendRequestCount)
            
            ChatsView()
                .tabItem {
                    Label("Chats", systemImage: "message.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .sheet(isPresented: $showingProfileSetup) {
            ProfileSetupView()
                .interactiveDismissDisabled(profiles.isEmpty && cloudKitService.currentUserProfile == nil)
        }
        .task {
            await checkProfileSetup()
            // Sync friendships from CloudKit so pending requests appear immediately
            await syncFriendshipsFromCloudKit()
            // Clean up CloudKit records for games completed/abandoned more than 24 hours ago
            await cloudKitService.cleanupOldGameRecords()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await syncFriendshipsFromCloudKit()
                }
            }
        }
        .onChange(of: cloudKitService.currentUserProfile) { _, newValue in
            // Re-check profile setup when current profile changes
            if newValue == nil {
                Task {
                    await checkProfileSetup()
                }
            }
        }
    }
    
    /// Pull friendships from CloudKit and insert/update locally so badges and lists are current
    private func syncFriendshipsFromCloudKit() async {
        guard cloudKitService.isAuthenticated,
              cloudKitService.currentUserRecordName != nil else {
            return
        }
        
        let currentUser = cloudKitService.currentUserRecordName
        
        do {
            let records = try await cloudKitService.fetchFriendships()
            
            // Build lookup of existing local friendships
            var existingByKey: [String: Friendship] = [:]
            for f in friendships {
                let key = f.userRecordName + "-" + f.friendRecordName
                existingByKey[key] = f
            }
            
            for record in records {
                guard let userRecordName = record["userRecordName"] as? String,
                      let friendRecordName = record["friendRecordName"] as? String,
                      let statusString = record["status"] as? String,
                      let status = FriendshipStatus(rawValue: statusString) else {
                    continue
                }
                
                let cloudKitRecordName = record.recordID.recordName
                let key = userRecordName + "-" + friendRecordName
                
                if let existing = existingByKey[key] {
                    // Update status if CloudKit has a newer status
                    if existing.status != status {
                        existing.status = status
                        if status == .accepted {
                            existing.acceptedAt = (record["acceptedAt"] as? Date) ?? Date()
                        }
                    }
                    if existing.cloudKitRecordName == nil {
                        existing.cloudKitRecordName = cloudKitRecordName
                    }
                } else {
                    // New friendship — determine display name based on perspective
                    let iAmSender = (userRecordName == currentUser)
                    let displayUsername: String
                    let displayName: String
                    
                    if iAmSender {
                        displayUsername = (record["friendUsername"] as? String) ?? "Unknown"
                        displayName = (record["friendDisplayName"] as? String) ?? "Unknown"
                    } else {
                        displayUsername = (record["userUsername"] as? String) ?? "Unknown"
                        displayName = (record["userDisplayName"] as? String) ?? "Unknown"
                    }
                    
                    let friendship = Friendship(
                        userRecordName: userRecordName,
                        friendRecordName: friendRecordName,
                        friendUsername: displayUsername,
                        friendDisplayName: displayName,
                        status: status
                    )
                    friendship.cloudKitRecordName = cloudKitRecordName
                    modelContext.insert(friendship)
                }
            }
            
            try? modelContext.save()
        } catch {
            print("⚠️ Failed to sync friendships at launch: \(error.localizedDescription)")
        }
    }
    
    private func checkProfileSetup() async {
        // Wait a bit for the view to load
        try? await Task.sleep(for: .milliseconds(100))
        
        // If user is signed out, show profile setup
        if cloudKitService.isSignedOut {
            showingProfileSetup = true
            return
        }
        
        // Check if user is authenticated
        guard cloudKitService.isAuthenticated else {
            return
        }
        
        // Check if there's a profile in CloudKit service
        if cloudKitService.currentUserProfile != nil {
            return
        }
        
        // Check if there's a local profile
        if let firstProfile = profiles.first {
            // Found a local profile, use it
            cloudKitService.currentUserProfile = firstProfile
            return
        }
        
        // No profile found, show setup
        showingProfileSetup = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
