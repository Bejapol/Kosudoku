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
    @State private var showingNewChat = false
    @State private var cloudKitService = CloudKitService.shared
    @State private var isLoading = false
    
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
