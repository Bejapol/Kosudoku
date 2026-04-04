//
//  ViewsEmoteBarView.swift
//  Kosudoku
//
//  Created by Paul Kim on 4/2/26.
//

import SwiftUI

/// Shared emote bar component used in game chat and lobby
struct EmoteBarView: View {
    let onEmoteTap: (GameEmote) -> Void
    let isUnlocked: Bool
    
    @State private var lastEmoteTime: Date = .distantPast
    
    var body: some View {
        if isUnlocked {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(GameEmote.allCases, id: \.rawValue) { emote in
                        Button {
                            // 2-second cooldown between emotes
                            let now = Date()
                            guard now.timeIntervalSince(lastEmoteTime) >= 2.0 else { return }
                            lastEmoteTime = now
                            onEmoteTap(emote)
                        } label: {
                            VStack(spacing: 2) {
                                Text(emote.emoji)
                                    .font(.title2)
                                Text(emote.label)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 56)
        } else {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                Text("Unlock emotes in the Store")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}
