//
//  GroupChatView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct GroupChatView: View {
    let groupChat: GroupChat
    @Environment(\.modelContext) private var modelContext
    @Query private var allMessages: [ChatMessage]
    @State private var messageText = ""
    @State private var cloudKitService = CloudKitService.shared
    @State private var cloudKitMessages: [ChatMessage] = []
    @State private var pollTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(groupMessages, id: \.stableID) { message in
                            ChatMessageBubble(
                                message: message,
                                isCurrentUser: message.senderRecordName == cloudKitService.currentUserRecordName
                            )
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("bottomAnchor")
                    }
                    .padding()
                }
                .onChange(of: groupMessages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
                .onAppear {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
            
            Divider()
            
            // Message input
            HStack {
                TextField("Message", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    Task {
                        await sendMessage()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .navigationTitle(groupChat.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchCloudKitMessages()
            startPolling()
        }
        .refreshable {
            await fetchCloudKitMessages()
        }
        .onDisappear {
            stopPolling()
        }
    }
    
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { await fetchCloudKitMessages() }
        }
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private var groupMessages: [ChatMessage] {
        // Use CloudKit messages as the source of truth.
        // Deduplicate by content+sender+timestamp to avoid showing the same message twice.
        var seen = Set<String>()
        var result: [ChatMessage] = []
        
        // CloudKit messages first (authoritative)
        for msg in cloudKitMessages {
            let key = "\(msg.senderRecordName)|\(msg.content)|\(Int(msg.timestamp.timeIntervalSince1970))"
            if seen.insert(key).inserted {
                result.append(msg)
            }
        }
        
        // Then any local-only messages not yet in CloudKit
        let localMessages = allMessages.filter { $0.groupChatID == groupChat.id.uuidString }
        for msg in localMessages {
            let key = "\(msg.senderRecordName)|\(msg.content)|\(Int(msg.timestamp.timeIntervalSince1970))"
            if seen.insert(key).inserted {
                result.append(msg)
            }
        }
        
        return result.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func fetchCloudKitMessages() async {
        do {
            let records = try await cloudKitService.fetchChatMessages(groupChatID: groupChat.id.uuidString)
            
            // Build a set of existing stable IDs so we only add truly new messages
            let existingIDs = Set(cloudKitMessages.map(\.stableID))
            var newMessages: [ChatMessage] = []
            
            for record in records {
                guard let senderRecordName = record["senderRecordName"] as? String,
                      let senderUsername = record["senderUsername"] as? String,
                      let content = record["content"] as? String else {
                    continue
                }
                
                let timestamp = (record["timestamp"] as? Date) ?? Date()
                let stableKey = "\(senderRecordName)|\(content)|\(Int(timestamp.timeIntervalSince1970))"
                
                if !existingIDs.contains(stableKey) {
                    let messageTypeRaw = (record["messageType"] as? String) ?? "text"
                    let messageType = ChatMessageType(rawValue: messageTypeRaw) ?? .text
                    
                    let message = ChatMessage(
                        senderRecordName: senderRecordName,
                        senderUsername: senderUsername,
                        content: content,
                        messageType: messageType,
                        groupChatID: groupChat.id.uuidString
                    )
                    message.timestamp = timestamp
                    newMessages.append(message)
                }
            }
            
            if !newMessages.isEmpty {
                cloudKitMessages.append(contentsOf: newMessages)
            }
        } catch {
            print("Failed to fetch group chat messages: \(error.localizedDescription)")
        }
    }
    
    private func sendMessage() async {
        guard !messageText.isEmpty,
              let senderRecordName = cloudKitService.currentUserRecordName,
              let username = cloudKitService.currentUserProfile?.username else {
            return
        }
        
        let message = ChatMessage(
            senderRecordName: senderRecordName,
            senderUsername: username,
            content: messageText,
            messageType: .text,
            groupChatID: groupChat.id.uuidString
        )
        
        do {
            try await cloudKitService.sendChatMessage(message, groupChatID: groupChat.id.uuidString)
            // Add to the in-memory list so it appears immediately;
            // the next poll will fetch it from CloudKit and replace this copy.
            cloudKitMessages.append(message)
            messageText = ""
        } catch {
            print("Error sending message: \(error)")
        }
    }
}



#Preview {
    NavigationStack {
        GroupChatView(groupChat: GroupChat(name: "Test Chat", creatorRecordName: "user1"))
            .modelContainer(for: ChatMessage.self, inMemory: true)
    }
}
