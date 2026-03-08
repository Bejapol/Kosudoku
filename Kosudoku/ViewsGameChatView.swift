//
//  GameChatView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct GameChatView: View {
    let gameSession: GameSession
    @Environment(\.modelContext) private var modelContext
    @Query private var allMessages: [ChatMessage]
    @State private var messageText = ""
    @State private var cloudKitService = CloudKitService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(gameMessages, id: \.id) { message in
                            if message.messageType == .system {
                                SystemMessageView(message: message)
                            } else {
                                ChatMessageBubble(
                                    message: message,
                                    isCurrentUser: message.senderRecordName == cloudKitService.currentUserRecordName
                                )
                            }
                        }
                    }
                    .padding()
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
        }
    }
    
    private var gameMessages: [ChatMessage] {
        allMessages.filter { $0.gameSessionID == gameSession.id }
            .sorted { $0.timestamp < $1.timestamp }
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
            
            modelContext.insert(message)
            try modelContext.save()
            
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
