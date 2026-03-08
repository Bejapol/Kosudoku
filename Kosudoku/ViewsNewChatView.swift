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
                            HStack {
                                Text(friendship.friendDisplayName)
                                Spacer()
                                if selectedMembers.contains(friendship.friendRecordName) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleMemberSelection(friendship.friendRecordName)
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
        
        let groupChat = GroupChat(
            name: chatName,
            creatorRecordName: creatorRecordName,
            memberRecordNames: Array(selectedMembers)
        )
        
        modelContext.insert(groupChat)
        
        do {
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
