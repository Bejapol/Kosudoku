//
//  GameChatView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct GameChatView: View {
    let gameSession: GameSession
    @Environment(\.modelContext) private var modelContext
    @Query private var allMessages: [ChatMessage]
    @State private var messageText = ""
    @State private var cloudKitService = CloudKitService.shared
    @State private var cloudKitMessages: [ChatMessage] = []
    @State private var pollTimer: Timer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(gameMessages, id: \.stableID) { message in
                                if message.messageType == .system {
                                    SystemMessageView(message: message)
                                } else {
                                    ChatMessageBubble(
                                        message: message,
                                        isCurrentUser: message.senderRecordName == cloudKitService.currentUserRecordName
                                    )
                                }
                            }
                            // Invisible anchor at the bottom
                            Color.clear
                                .frame(height: 1)
                                .id("bottomAnchor")
                        }
                        .padding()
                    }
                    .onChange(of: gameMessages.count) { _, _ in
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
            .navigationTitle("Game Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                // Suppress banners while viewing this game chat
                ChatNotificationManager.shared.activeGameChatRecordName = gameSession.cloudKitRecordName
                await fetchCloudKitMessages()
                startPolling()
            }
            .refreshable {
                await fetchCloudKitMessages()
            }
            .onDisappear {
                stopPolling()
                ChatNotificationManager.shared.activeGameChatRecordName = nil
            }
        }
    }
    
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task {
                await fetchCloudKitMessages()
            }
        }
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private var gameMessages: [ChatMessage] {
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
        let localMessages = allMessages.filter { $0.gameSessionID == gameSession.id }
        for msg in localMessages {
            let key = "\(msg.senderRecordName)|\(msg.content)|\(Int(msg.timestamp.timeIntervalSince1970))"
            if seen.insert(key).inserted {
                result.append(msg)
            }
        }
        
        return result.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func fetchCloudKitMessages() async {
        guard let gameRecordName = gameSession.cloudKitRecordName else { return }
        
        do {
            let records = try await cloudKitService.fetchChatMessages(gameRecordName: gameRecordName)
            
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
                        gameSession: gameSession
                    )
                    message.timestamp = timestamp
                    newMessages.append(message)
                }
            }
            
            if !newMessages.isEmpty {
                cloudKitMessages.append(contentsOf: newMessages)
            }
        } catch {
            print("⚠️ Failed to fetch chat messages from CloudKit: \(error.localizedDescription)")
        }
    }
    
    private func sendMessage() async {
        guard !messageText.isEmpty,
              let senderRecordName = cloudKitService.currentUserRecordName,
              let username = cloudKitService.currentUserProfile?.username,
              let gameRecordName = gameSession.cloudKitRecordName else {
            return
        }
        
        let message = ChatMessage(
            senderRecordName: senderRecordName,
            senderUsername: username,
            content: messageText,
            messageType: .text,
            gameSession: gameSession
        )
        
        do {
            try await cloudKitService.sendChatMessage(message, gameRecordName: gameRecordName)
            // Add to the in-memory list so it appears immediately;
            // the next poll will fetch it from CloudKit and replace this copy.
            cloudKitMessages.append(message)
            messageText = ""
        } catch {
            print("Error sending message: \(error)")
        }
    }
}

struct SystemMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            Spacer()
        }
    }
}

#Preview {
    GameChatView(gameSession: GameSession(hostRecordName: "host", difficulty: .medium, puzzleData: "{}", solutionData: "{}"))
        .modelContainer(for: ChatMessage.self, inMemory: true)
}
