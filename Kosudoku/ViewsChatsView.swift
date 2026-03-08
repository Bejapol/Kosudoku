//
//  ChatsView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct ChatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groupChats: [GroupChat]
    @State private var showingNewChat = false
    
    var body: some View {
        NavigationStack {
            List {
                if groupChats.isEmpty {
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
