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
    @Query private var groupChats: [GroupChat]
    @State private var notificationManager = ChatNotificationManager.shared
    
    private var waitingGamesCount: Int {
        gameSessions.filter { $0.status == .waiting }.count
    }
    
    private var pendingFriendRequestCount: Int {
        guard let currentUser = cloudKitService.currentUserRecordName else { return 0 }
        // Only count requests where I am the recipient (friendRecordName), not ones I sent
        return friendships.filter { $0.status == .pending && $0.friendRecordName == currentUser }.count
    }
    
    var body: some View {
        ZStack(alignment: .top) {
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
            
            // In-app notification banner
            if let banner = notificationManager.currentBanner {
                ChatBannerView(
                    banner: banner,
                    onTap: {
                        notificationManager.dismissCurrentBanner()
                        switch banner.bannerType {
                        case .gameChat, .groupChat:
                            selectedTab = 2 // Chats tab
                        case .friendRequest:
                            selectedTab = 1 // Friends tab
                        case .gameInvite:
                            selectedTab = 0 // Home tab (game invitations)
                        }
                    },
                    onDismiss: {
                        notificationManager.dismissCurrentBanner()
                    }
                )
                .padding(.top, 4)
                .zIndex(100)
                .animation(.spring(duration: 0.4), value: notificationManager.currentBanner?.id)
            }
        }
        .sheet(isPresented: $showingProfileSetup) {
            ProfileSetupView()
                .interactiveDismissDisabled(profiles.isEmpty && cloudKitService.currentUserProfile == nil)
        }
        .task {
            await checkProfileSetup()
            // Snapshot locally known friend request IDs BEFORE syncing from CloudKit.
            // These are requests the user has already seen in a previous session.
            let preSyncFriendIDs = Set(friendships.compactMap { $0.cloudKitRecordName })
            // Sync friendships from CloudKit so pending requests appear immediately
            await syncFriendshipsFromCloudKit()
            // Clean up CloudKit records for games completed/abandoned more than 24 hours ago
            await cloudKitService.cleanupOldGameRecords()
            // Subscribe to chat notifications for existing chats
            await subscribeToExistingChats(preSyncFriendIDs: preSyncFriendIDs)
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
    
    /// Subscribe to CloudKit push notifications and start monitoring for all chats, friend requests, and game invites
    private func subscribeToExistingChats(preSyncFriendIDs: Set<String> = []) async {
        // Seed seen items so we don't get banners for existing data
        await seedSeenMessages()
        await seedSeenFriendRequests(preSyncFriendIDs: preSyncFriendIDs)
        await seedSeenGameInvites()
        
        // Subscribe and monitor group chats
        for chat in groupChats {
            let chatID = chat.id.uuidString
            await notificationManager.subscribeToGroupChat(groupChatID: chatID)
            notificationManager.monitorGroupChat(groupChatID: chatID)
        }
        // Subscribe and monitor active/waiting game sessions
        for session in gameSessions where session.status == .active || session.status == .waiting {
            if let recordName = session.cloudKitRecordName {
                await notificationManager.subscribeToGameChat(gameRecordName: recordName)
                notificationManager.monitorGameChat(gameRecordName: recordName)
            }
        }
        
        // Subscribe to friend requests and game invites
        await notificationManager.subscribeToFriendRequests()
        await notificationManager.subscribeToGameInvites()
        
        // Always start the poll loop so friend requests, game invites,
        // and new group chats are detected even if no chats exist yet
        notificationManager.startPolling()
    }
    
    /// Fetch existing messages from all chats so we don't show banners for old messages
    private func seedSeenMessages() async {
        // Seed game chat messages
        for session in gameSessions where session.status == .active || session.status == .waiting {
            guard let recordName = session.cloudKitRecordName else { continue }
            if let records = try? await cloudKitService.fetchChatMessages(gameRecordName: recordName) {
                let stableIDs = records.compactMap { record -> String? in
                    guard let sender = record["senderRecordName"] as? String,
                          let content = record["content"] as? String else { return nil }
                    let timestamp = (record["timestamp"] as? Date) ?? Date()
                    return "\(sender)|\(content)|\(Int(timestamp.timeIntervalSince1970))"
                }
                notificationManager.markMessagesSeen(stableIDs)
            }
        }
        // Seed group chat messages
        for chat in groupChats {
            if let records = try? await cloudKitService.fetchChatMessages(groupChatID: chat.id.uuidString) {
                let stableIDs = records.compactMap { record -> String? in
                    guard let sender = record["senderRecordName"] as? String,
                          let content = record["content"] as? String else { return nil }
                    let timestamp = (record["timestamp"] as? Date) ?? Date()
                    return "\(sender)|\(content)|\(Int(timestamp.timeIntervalSince1970))"
                }
                notificationManager.markMessagesSeen(stableIDs)
            }
        }
    }
    
    /// Seed existing friend requests so we don't show banners for old requests.
    /// Accepted friendships are always seeded. Pending requests are only seeded
    /// if they were already known locally before the CloudKit sync (i.e., the user
    /// saw them in a previous session). New pending requests that just arrived
    /// will trigger banners.
    private func seedSeenFriendRequests(preSyncFriendIDs: Set<String> = []) async {
        // Mark all accepted friendships as seen
        let acceptedIDs = friendships
            .filter { $0.status == .accepted }
            .compactMap { $0.cloudKitRecordName }
        notificationManager.markFriendRequestsSeen(acceptedIDs)
        
        // Mark pending requests that the user already knew about (pre-sync) as seen
        let preSyncPendingIDs = friendships
            .filter { $0.status == .pending }
            .compactMap { $0.cloudKitRecordName }
            .filter { preSyncFriendIDs.contains($0) }
        notificationManager.markFriendRequestsSeen(preSyncPendingIDs)
    }
    
    /// Seed existing game invites so we don't show banners for old invites
    private func seedSeenGameInvites() async {
        // Mark all locally known waiting/active game sessions as seen
        let gameInviteIDs = gameSessions.compactMap { $0.cloudKitRecordName }
        notificationManager.markGameInvitesSeen(gameInviteIDs)
        
        // Also fetch from CloudKit
        if let records = try? await cloudKitService.fetchInvitedGameSessions() {
            let recordNames = records.map { $0.recordID.recordName }
            notificationManager.markGameInvitesSeen(recordNames)
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
        
        // No local profile — try to recover from CloudKit (e.g. after reinstall)
        if let ownerRecordName = cloudKitService.currentUserRecordName,
           let cloudProfile = try? await cloudKitService.fetchUserProfileByOwner(ownerRecordName: ownerRecordName) {
            // Save to local SwiftData so future launches find it
            modelContext.insert(cloudProfile)
            try? modelContext.save()
            cloudKitService.currentUserProfile = cloudProfile
            return
        }
        
        // No profile found anywhere, show setup
        showingProfileSetup = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
