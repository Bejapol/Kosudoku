//
//  NewChatView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct NewChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var friendships: [Friendship]
    @State private var chatName = ""
    @State private var selectedMembers: Set<String> = []
    @State private var cloudKitService = CloudKitService.shared
    @State private var isCreating = false
    
    /// Returns the record name of the other person in the friendship
    private func friendRecordName(for friendship: Friendship) -> String {
        let currentUser = cloudKitService.currentUserRecordName ?? ""
        if friendship.userRecordName == currentUser {
            return friendship.friendRecordName
        } else {
            return friendship.userRecordName
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Chat Details") {
                    TextField("Chat Name", text: $chatName)
                }
                
                Section("Select Members") {
                    if acceptedFriends.isEmpty {
                        Text("No friends to add")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(acceptedFriends, id: \.id) { friendship in
                            let otherRecordName = friendRecordName(for: friendship)
                            HStack {
                                Text(friendship.friendDisplayName)
                                Spacer()
                                if selectedMembers.contains(otherRecordName) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleMemberSelection(otherRecordName)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createChat()
                        }
                    }
                    .disabled(chatName.isEmpty || selectedMembers.isEmpty || isCreating)
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
        }
    }
    
    private var acceptedFriends: [Friendship] {
        friendships.filter { $0.status == .accepted }
    }
    
    private func toggleMemberSelection(_ recordName: String) {
        if selectedMembers.contains(recordName) {
            selectedMembers.remove(recordName)
        } else {
            selectedMembers.insert(recordName)
        }
    }
    
    private func createChat() async {
        guard let creatorRecordName = cloudKitService.currentUserRecordName else {
            return
        }
        
        isCreating = true
        
        // Include the creator in the member list so all participants
        // can find this chat via the memberRecordNames query
        var allMembers = Array(selectedMembers)
        if !allMembers.contains(creatorRecordName) {
            allMembers.append(creatorRecordName)
        }
        
        let groupChat = GroupChat(
            name: chatName,
            creatorRecordName: creatorRecordName,
            memberRecordNames: allMembers
        )
        
        modelContext.insert(groupChat)
        
        do {
            // Save to CloudKit so other members can see the chat
            try await cloudKitService.saveGroupChat(groupChat)
            try modelContext.save()
            isCreating = false
            dismiss()
        } catch {
            print("Error creating chat: \(error)")
            isCreating = false
        }
    }
}

#Preview {
    NewChatView()
        .modelContainer(for: Friendship.self, inMemory: true)
}
