//
//  FriendsView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var friendships: [Friendship]
    @State private var searchText = ""
    @State private var showingAddFriend = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Friends") {
                    if acceptedFriends.isEmpty {
                        Text("No friends yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(acceptedFriends, id: \.id) { friendship in
                            FriendRow(friendship: friendship)
                        }
                    }
                }
                
                if !pendingRequests.isEmpty {
                    Section("Pending Requests") {
                        ForEach(pendingRequests, id: \.id) { friendship in
                            PendingRequestRow(friendship: friendship) {
                                acceptFriendRequest(friendship)
                            } onDecline: {
                                declineFriendRequest(friendship)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .searchable(text: $searchText, prompt: "Search friends")
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
        }
    }
    
    private var acceptedFriends: [Friendship] {
        let filtered = friendships.filter { $0.status == .accepted }
        if searchText.isEmpty {
            return filtered
        }
        return filtered.filter {
            $0.friendUsername.localizedCaseInsensitiveContains(searchText) ||
            $0.friendDisplayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var pendingRequests: [Friendship] {
        friendships.filter { $0.status == .pending }
    }
    
    private func acceptFriendRequest(_ friendship: Friendship) {
        friendship.status = .accepted
        friendship.acceptedAt = Date()
        try? modelContext.save()
    }
    
    private func declineFriendRequest(_ friendship: Friendship) {
        modelContext.delete(friendship)
        try? modelContext.save()
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
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
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
