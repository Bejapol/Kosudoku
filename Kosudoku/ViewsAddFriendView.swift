//
//  AddFriendView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import CloudKit

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [CKRecord] = []
    @State private var isSearching = false
    @State private var cloudKitService = CloudKitService.shared
    
    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    ProgressView()
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
            .searchable(text: $searchText, prompt: "Search by username")
            .onChange(of: searchText) { oldValue, newValue in
                Task {
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
        
        do {
            let results = try await cloudKitService.searchUsers(username: searchText)
            searchResults = results
        } catch {
            print("Search error: \(error)")
            searchResults = []
        }
        
        isSearching = false
    }
    
    private func sendFriendRequest(_ record: CKRecord) async {
        do {
            guard let username = record["username"] as? String,
                  let displayName = record["displayName"] as? String else {
                return
            }
            
            try await cloudKitService.sendFriendRequest(
                to: record.recordID.recordName,
                friendUsername: username,
                friendDisplayName: displayName
            )
            
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
