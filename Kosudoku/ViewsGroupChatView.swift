//
//  GroupChatView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct GroupChatView: View {
    let groupChat: GroupChat
    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [ChatMessage]
    @State private var messageText = ""
    @State private var cloudKitService = CloudKitService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(groupMessages, id: \.id) { message in
                        ChatMessageBubble(message: message, isCurrentUser: message.senderRecordName == cloudKitService.currentUserRecordName)
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
        .navigationTitle(groupChat.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var groupMessages: [ChatMessage] {
        messages.filter { $0.groupChatID == groupChat.id.uuidString }
            .sorted { $0.timestamp < $1.timestamp }
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
            
            modelContext.insert(message)
            try modelContext.save()
            
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
