//
//  FriendsView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var friendships: [Friendship]
    @State private var showingAddFriend = false
    @State private var isSyncing = false
    @State private var friendToRemove: Friendship?
    @State private var showingRemoveAlert = false
    @State private var friendToBlock: Friendship?
    @State private var showingBlockAlert = false
    private let cloudKitService = CloudKitService.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ContactsInviteView(friendships: friendships)
                    } label: {
                        Label("Find Friends from Contacts", systemImage: "person.crop.rectangle.stack")
                    }
                }
                
                Section("Friends") {
                    if acceptedFriends.isEmpty {
                        Text("No friends yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(acceptedFriends, id: \.id) { friendship in
                            FriendRow(
                                friendship: friendship,
                                otherRecordName: otherPersonRecordName(friendship)
                            )
                            .swipeActions(edge: .trailing) {
                                Button("Remove", role: .destructive) {
                                    friendToRemove = friendship
                                    showingRemoveAlert = true
                                }
                                Button("Block") {
                                    friendToBlock = friendship
                                    showingBlockAlert = true
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
                
                if !receivedRequests.isEmpty {
                    Section("Friend Requests") {
                        ForEach(receivedRequests, id: \.id) { friendship in
                            PendingRequestRow(
                                friendship: friendship,
                                otherRecordName: otherPersonRecordName(friendship)
                            ) {
                                acceptFriendRequest(friendship)
                            } onDecline: {
                                declineFriendRequest(friendship)
                            }
                        }
                    }
                }
                
                if !sentRequests.isEmpty {
                    Section("Sent Requests") {
                        ForEach(sentRequests, id: \.id) { friendship in
                            HStack {
                                OnlineStatusIndicator(ownerRecordName: otherPersonRecordName(friendship))
                                
                                VStack(alignment: .leading) {
                                    Text(friendship.friendDisplayName)
                                        .font(.headline)
                                    Text("@\(friendship.friendUsername)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("Pending")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if !blockedUsers.isEmpty {
                    Section("Blocked Users") {
                        ForEach(blockedUsers, id: \.id) { friendship in
                            HStack {
                                OnlineStatusIndicator(ownerRecordName: otherPersonRecordName(friendship))
                                
                                VStack(alignment: .leading) {
                                    Text(friendship.friendDisplayName)
                                        .font(.headline)
                                    Text("@\(friendship.friendUsername)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Unblock") {
                                    unblockUser(friendship)
                                }
                                .tint(.green)
                                Button("Remove", role: .destructive) {
                                    friendToRemove = friendship
                                    showingRemoveAlert = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .refreshable {
                await syncFriendships()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
            }
            .task {
                await cloudKitService.subscribeToFriendRequests()
                await syncFriendships()
            }
            .alert("Remove Friend", isPresented: $showingRemoveAlert) {
                Button("Remove", role: .destructive) {
                    if let friendship = friendToRemove {
                        removeFriend(friendship)
                    }
                    friendToRemove = nil
                }
                Button("Cancel", role: .cancel) {
                    friendToRemove = nil
                }
            } message: {
                if let friendship = friendToRemove {
                    Text("Are you sure you want to remove \(friendship.friendDisplayName) from your friends?")
                }
            }
            .alert("Block User", isPresented: $showingBlockAlert) {
                Button("Block", role: .destructive) {
                    if let friendship = friendToBlock {
                        blockUser(friendship)
                    }
                    friendToBlock = nil
                }
                Button("Cancel", role: .cancel) {
                    friendToBlock = nil
                }
            } message: {
                if let friendship = friendToBlock {
                    Text("Block \(friendship.friendDisplayName)? They won't be able to send you game invites or friend requests.")
                }
            }
        }
    }
    
    /// Returns the owner record name of the other person in the friendship
    private func otherPersonRecordName(_ friendship: Friendship) -> String {
        let currentUser = cloudKitService.currentUserRecordName ?? ""
        if friendship.userRecordName == currentUser {
            return friendship.friendRecordName
        } else {
            return friendship.userRecordName
        }
    }
    
    private var acceptedFriends: [Friendship] {
        friendships.filter { $0.status == .accepted }
    }
    
    private var blockedUsers: [Friendship] {
        friendships.filter { $0.status == .blocked }
    }
    
    /// Requests sent TO me (I am the friendRecordName — the recipient)
    private var receivedRequests: [Friendship] {
        let currentUser = cloudKitService.currentUserRecordName
        return friendships.filter { $0.status == .pending && $0.friendRecordName == currentUser }
    }
    
    /// Requests I sent (I am the userRecordName — the sender)
    private var sentRequests: [Friendship] {
        let currentUser = cloudKitService.currentUserRecordName
        return friendships.filter { $0.status == .pending && $0.userRecordName == currentUser }
    }
    
    private func syncFriendships() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        let currentUser = cloudKitService.currentUserRecordName
        
        do {
            let records = try await cloudKitService.fetchFriendships()
            
            // Build a lookup of existing local friendships by their user+friend key
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
                    // Determine who the "other person" is from our perspective
                    let iAmSender = (userRecordName == currentUser)
                    let displayUsername: String
                    let displayName: String
                    
                    if iAmSender {
                        // I sent it — show the friend's info
                        displayUsername = (record["friendUsername"] as? String) ?? "Unknown"
                        displayName = (record["friendDisplayName"] as? String) ?? "Unknown"
                    } else {
                        // I received it — show the sender's info
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
            
            try modelContext.save()
        } catch {
            print("Error syncing friendships: \(error)")
        }
    }
    
    private func acceptFriendRequest(_ friendship: Friendship) {
        friendship.status = .accepted
        friendship.acceptedAt = Date()
        try? modelContext.save()
        
        // Update the original CloudKit record directly.
        // This requires Write permission for _world role on the Friendship record type
        // in CloudKit Dashboard > Schema > Security Roles.
        if let ckRecordName = friendship.cloudKitRecordName {
            Task {
                do {
                    try await cloudKitService.updateFriendshipStatus(
                        cloudKitRecordName: ckRecordName,
                        status: .accepted
                    )
                } catch {
                    print("❌ Failed to update friendship in CloudKit: \(error)")
                }
            }
        } else {
            print("⚠️ No cloudKitRecordName on friendship — cannot update CloudKit")
        }
    }
    
    private func declineFriendRequest(_ friendship: Friendship) {
        let ckRecordName = friendship.cloudKitRecordName
        modelContext.delete(friendship)
        try? modelContext.save()
        
        // Delete from CloudKit
        if let ckRecordName {
            Task {
                try? await cloudKitService.deleteFriendship(cloudKitRecordName: ckRecordName)
            }
        }
    }
    
    private func removeFriend(_ friendship: Friendship) {
        let ckRecordName = friendship.cloudKitRecordName
        modelContext.delete(friendship)
        try? modelContext.save()
        
        // Delete from CloudKit
        if let ckRecordName {
            Task {
                try? await cloudKitService.deleteFriendship(cloudKitRecordName: ckRecordName)
            }
        }
    }
    
    private func blockUser(_ friendship: Friendship) {
        friendship.status = .blocked
        try? modelContext.save()
        
        if let ckRecordName = friendship.cloudKitRecordName {
            Task {
                try? await cloudKitService.updateFriendshipStatus(
                    cloudKitRecordName: ckRecordName,
                    status: .blocked
                )
            }
        }
    }
    
    private func unblockUser(_ friendship: Friendship) {
        friendship.status = .accepted
        try? modelContext.save()
        
        if let ckRecordName = friendship.cloudKitRecordName {
            Task {
                try? await cloudKitService.updateFriendshipStatus(
                    cloudKitRecordName: ckRecordName,
                    status: .accepted
                )
            }
        }
    }
}

struct FriendRow: View {
    let friendship: Friendship
    let otherRecordName: String
    @State private var showingProfile = false
    @State private var profileImageData: Data?
    @State private var profileFrame: ProfileFrame?
    @State private var rankTier: RankTier?
    @State private var cloudKitService = CloudKitService.shared
    
    // Static cache for friend profile data
    private static var photoCache: [String: Data] = [:]
    private static var frameCache: [String: ProfileFrame] = [:]
    private static var rankCache: [String: RankTier] = [:]
    
    var body: some View {
        Button {
            showingProfile = true
        } label: {
            HStack {
                ProfilePhotoView(
                    imageData: profileImageData,
                    displayName: friendship.friendDisplayName,
                    size: 40,
                    profileFrame: profileFrame
                )
                .overlay(alignment: .bottomTrailing) {
                    OnlineStatusIndicator(ownerRecordName: otherRecordName)
                }
                
                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Text(friendship.friendDisplayName)
                            .font(.headline)
                        
                        if let tier = rankTier {
                            RankTierBadge(tier: tier, showLabel: false, size: 12)
                        }
                    }
                    Text("@\(friendship.friendUsername)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .task {
            await loadPhoto()
        }
        .sheet(isPresented: $showingProfile) {
            PlayerProfileView(ownerRecordName: otherRecordName)
        }
    }
    
    private func loadPhoto() async {
        if let cached = Self.photoCache[otherRecordName] {
            if profileImageData == nil { profileImageData = cached }
        }
        if let cachedFrame = Self.frameCache[otherRecordName] {
            profileFrame = cachedFrame
        }
        if let cachedRank = Self.rankCache[otherRecordName] {
            rankTier = cachedRank
        }
        if Self.photoCache[otherRecordName] != nil {
            return
        }
        do {
            if let profile = try await cloudKitService.fetchUserProfileByOwner(ownerRecordName: otherRecordName) {
                profileImageData = profile.avatarImageData
                profileFrame = profile.activeProfileFrame
                rankTier = profile.rankTier
                if let data = profile.avatarImageData {
                    Self.photoCache[otherRecordName] = data
                }
                Self.frameCache[otherRecordName] = profile.activeProfileFrame
                Self.rankCache[otherRecordName] = profile.rankTier
            }
        } catch {
            print("Failed to load friend photo: \(error)")
        }
    }
}

struct PendingRequestRow: View {
    let friendship: Friendship
    let otherRecordName: String
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack {
            OnlineStatusIndicator(ownerRecordName: otherRecordName)
            
            VStack(alignment: .leading) {
                Text(friendship.friendDisplayName)
                    .font(.headline)
                Text("@\(friendship.friendUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Accept") {
                onAccept()
            }
            .buttonStyle(.bordered)
            .tint(.green)
            
            Button("Decline") {
                onDecline()
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

#Preview {
    FriendsView()
        .modelContainer(for: Friendship.self, inMemory: true)
}
