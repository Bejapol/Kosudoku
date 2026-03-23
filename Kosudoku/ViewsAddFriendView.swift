//
//  AddFriendView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var searchResults: [CKRecord] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var cloudKitService = CloudKitService.shared
    
    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    ProgressView()
                } else if let error = searchError {
                    Text(error)
                        .foregroundColor(.red)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Text("No users found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(searchResults, id: \.recordID) { record in
                        UserSearchResultRow(record: record) {
                            Task {
                                await sendFriendRequest(record)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by username or display name")
            .onSubmit(of: .search) {
                Task {
                    await performSearch()
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                // Debounce: wait briefly before searching to avoid rapid queries
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    await performSearch()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        do {
            let results = try await cloudKitService.searchUsers(username: searchText)
            // Filter out the current user so you can't friend yourself
            let currentUser = cloudKitService.currentUserRecordName
            searchResults = results.filter { record in
                // Compare against ownerRecordName (the iCloud user ID stored on the profile)
                let ownerRecordName = record["ownerRecordName"] as? String
                return ownerRecordName != currentUser
            }
        } catch {
            print("Search error: \(error)")
            searchResults = []
            searchError = "Search failed: \(error.localizedDescription)"
        }
        
        isSearching = false
    }
    
    private func sendFriendRequest(_ record: CKRecord) async {
        do {
            guard let username = record["username"] as? String,
                  let displayName = record["displayName"] as? String,
                  let currentUser = cloudKitService.currentUserRecordName else {
                return
            }
            
            // Use ownerRecordName (the friend's iCloud user ID) instead of the
            // UserProfile record ID, so the recipient's device can match it against
            // their own currentUserRecordName.
            guard let friendOwnerRecordName = record["ownerRecordName"] as? String else {
                print("⚠️ UserProfile record has no ownerRecordName — friend may need to re-save their profile")
                return
            }
            
            let ckRecordName = try await cloudKitService.sendFriendRequest(
                to: friendOwnerRecordName,
                friendUsername: username,
                friendDisplayName: displayName
            )
            
            // Save locally so it appears in the sender's Friends list
            let friendship = Friendship(
                userRecordName: currentUser,
                friendRecordName: friendOwnerRecordName,
                friendUsername: username,
                friendDisplayName: displayName,
                status: .pending
            )
            friendship.cloudKitRecordName = ckRecordName
            modelContext.insert(friendship)
            try? modelContext.save()
            
            dismiss()
        } catch {
            print("Error sending friend request: \(error)")
        }
    }
}

struct UserSearchResultRow: View {
    let record: CKRecord
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.purple.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    if let displayName = record["displayName"] as? String {
                        Text(displayName.prefix(1))
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
            
            VStack(alignment: .leading) {
                if let displayName = record["displayName"] as? String {
                    Text(displayName)
                        .font(.headline)
                }
                if let username = record["username"] as? String {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }
}

#Preview {
    AddFriendView()
}
