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
    private let cloudKitService = CloudKitService.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section("Friends") {
                    if acceptedFriends.isEmpty {
                        Text("No friends yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(acceptedFriends, id: \.id) { friendship in
                            Button {
                                friendToRemove = friendship
                                showingRemoveAlert = true
                            } label: {
                                FriendRow(friendship: friendship)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if !receivedRequests.isEmpty {
                    Section("Friend Requests") {
                        ForEach(receivedRequests, id: \.id) { friendship in
                            PendingRequestRow(friendship: friendship) {
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
        }
    }
    
    private var acceptedFriends: [Friendship] {
        friendships.filter { $0.status == .accepted }
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
}

struct FriendRow: View {
    let friendship: Friendship
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(friendship.friendDisplayName.prefix(1))
                        .foregroundColor(.white)
                        .font(.headline)
                }
            
            VStack(alignment: .leading) {
                Text(friendship.friendDisplayName)
                    .font(.headline)
                Text("@\(friendship.friendUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct PendingRequestRow: View {
    let friendship: Friendship
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack {
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
