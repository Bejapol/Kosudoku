//
//  ChatsView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct ChatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groupChats: [GroupChat]
    @Query private var chatMessages: [ChatMessage]
    @State private var showingNewChat = false
    @State private var cloudKitService = CloudKitService.shared
    @State private var isLoading = false
    @State private var chatToDelete: GroupChat?
    @State private var showingDeleteAlert = false
    @State private var chatToLeave: GroupChat?
    @State private var showingLeaveAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                if groupChats.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "No Chats",
                        systemImage: "message",
                        description: Text("Create a group chat to get started")
                    )
                } else {
                    ForEach(groupChats, id: \.id) { chat in
                        NavigationLink {
                            GroupChatView(groupChat: chat)
                        } label: {
                            GroupChatRow(groupChat: chat)
                        }
                        .swipeActions(edge: .trailing) {
                            if chat.creatorRecordName == cloudKitService.currentUserRecordName {
                                Button("Delete", role: .destructive) {
                                    chatToDelete = chat
                                    showingDeleteAlert = true
                                }
                            }
                            Button("Leave") {
                                chatToLeave = chat
                                showingLeaveAlert = true
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatView()
            }
            .task {
                await fetchCloudKitChats()
            }
            .refreshable {
                await fetchCloudKitChats()
            }
            .alert("Delete Chat", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let chat = chatToDelete {
                        deleteChat(chat)
                    }
                    chatToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    chatToDelete = nil
                }
            } message: {
                Text("This will delete the chat and all messages for everyone. This cannot be undone.")
            }
            .alert("Leave Chat", isPresented: $showingLeaveAlert) {
                Button("Leave", role: .destructive) {
                    if let chat = chatToLeave {
                        leaveChat(chat)
                    }
                    chatToLeave = nil
                }
                Button("Cancel", role: .cancel) {
                    chatToLeave = nil
                }
            } message: {
                Text("You will no longer see messages in this chat.")
            }
        }
    }
    
    // MARK: - Chat Management
    
    private func deleteChat(_ chat: GroupChat) {
        let ckRecordName = chat.cloudKitRecordName
        let groupChatID = chat.id.uuidString
        
        // Delete local messages for this chat
        let localMessages = chatMessages.filter { $0.groupChatID == groupChatID }
        for message in localMessages {
            modelContext.delete(message)
        }
        
        // Delete the local chat
        modelContext.delete(chat)
        try? modelContext.save()
        
        // Delete from CloudKit
        if let ckRecordName {
            Task {
                try? await cloudKitService.deleteGroupChat(
                    cloudKitRecordName: ckRecordName,
                    groupChatID: groupChatID
                )
            }
        }
    }
    
    private func leaveChat(_ chat: GroupChat) {
        guard let currentUser = cloudKitService.currentUserRecordName else { return }
        let ckRecordName = chat.cloudKitRecordName
        let hasOtherMembers = chat.memberRecordNames.contains { $0 != currentUser } ||
                              (chat.creatorRecordName != currentUser)
        
        if !hasOtherMembers {
            // Last member — delete the entire chat
            deleteChat(chat)
            return
        }
        
        // Remove locally
        modelContext.delete(chat)
        try? modelContext.save()
        
        // Update CloudKit
        if let ckRecordName {
            Task {
                try? await cloudKitService.leaveGroupChat(
                    cloudKitRecordName: ckRecordName,
                    memberRecordName: currentUser
                )
            }
        }
    }
    
    /// Fetch group chats from CloudKit and merge into local SwiftData
    private func fetchCloudKitChats() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let records = try await cloudKitService.fetchGroupChats()
            let localChatIDs = Set(groupChats.map { $0.id.uuidString })
            
            for record in records {
                guard let groupChatID = record["groupChatID"] as? String else { continue }
                
                // Skip if we already have this chat locally
                if localChatIDs.contains(groupChatID) {
                    // Update the cloudKitRecordName if missing
                    if let existing = groupChats.first(where: { $0.id.uuidString == groupChatID }),
                       existing.cloudKitRecordName == nil {
                        existing.cloudKitRecordName = record.recordID.recordName
                    }
                    continue
                }
                
                // Create a local copy of the chat from CloudKit
                guard let name = record["name"] as? String,
                      let creatorRecordName = record["creatorRecordName"] as? String,
                      let chatUUID = UUID(uuidString: groupChatID) else {
                    continue
                }
                
                let memberRecordNames = (record["memberRecordNames"] as? [String]) ?? []
                
                let groupChat = GroupChat(
                    name: name,
                    creatorRecordName: creatorRecordName,
                    memberRecordNames: memberRecordNames
                )
                // Preserve the original UUID so messages match via groupChatID
                groupChat.id = chatUUID
                groupChat.cloudKitRecordName = record.recordID.recordName
                groupChat.createdAt = (record["createdAt"] as? Date) ?? Date()
                
                modelContext.insert(groupChat)
            }
            
            try? modelContext.save()
            
            // Subscribe to push notifications for all group chats
            for chat in groupChats {
                await ChatNotificationManager.shared.subscribeToGroupChat(groupChatID: chat.id.uuidString)
            }
        } catch {
            print("Failed to fetch group chats from CloudKit: \(error)")
        }
    }
}

struct GroupChatRow: View {
    let groupChat: GroupChat
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.green.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.white)
                }
            
            VStack(alignment: .leading) {
                Text(groupChat.name)
                    .font(.headline)
                Text("\(groupChat.memberRecordNames.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    ChatsView()
        .modelContainer(for: GroupChat.self, inMemory: true)
}
