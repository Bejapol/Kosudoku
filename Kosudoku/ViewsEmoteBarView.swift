//
//  ViewsEmoteBarView.swift
//  Kosudoku
//
//  Created by Paul Kim on 4/2/26.
//

import SwiftUI

// MARK: - Emote Event

/// Represents an emote that should be animated on screen
struct EmoteEvent: Identifiable {
    let id = UUID()
    let emote: GameEmote
    let senderUsername: String
    let isCurrentUser: Bool
}

// MARK: - Emote Animation Overlay

/// Manages emote animation state as a reference type so closures
/// can reliably mutate it from DispatchQueue callbacks.
@Observable
class EmoteAnimationState {
    var displayedEvent: EmoteEvent?
    var phase: AnimationPhase = .idle
    
    enum AnimationPhase {
        case idle
        case scaleIn
        case floatUp
    }
}

/// Full-screen animated emote overlay — emoji scales up, floats upward, and fades out.
struct EmoteAnimationOverlay: View {
    @Binding var emoteEvent: EmoteEvent?
    @State private var state = EmoteAnimationState()
    
    var body: some View {
        ZStack {
            if let event = state.displayedEvent {
                VStack(spacing: 8) {
                    Text(event.emote.emoji)
                        .font(.system(size: 100))
                    
                    Text(event.senderUsername)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                }
                .scaleEffect(state.phase == .idle ? 0.2 : 1.0)
                .offset(y: state.phase == .floatUp ? -120 : 0)
                .opacity(state.phase == .idle ? 0 : (state.phase == .floatUp ? 0 : 1))
            }
        }
        .allowsHitTesting(false)
        .onChange(of: emoteEvent?.id) { _, newID in
            guard newID != nil, let event = emoteEvent else { return }
            startAnimation(for: event)
        }
    }
    
    private func startAnimation(for event: EmoteEvent) {
        // Reset immediately
        state.phase = .idle
        state.displayedEvent = event
        
        // Phase 1: Spring scale in (next run loop so SwiftUI processes the reset)
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                state.phase = .scaleIn
            }
        }
        
        // Phase 2: Float up and fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 1.4)) {
                state.phase = .floatUp
            }
        }
        
        // Phase 3: Cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            state.phase = .idle
            state.displayedEvent = nil
            emoteEvent = nil
        }
    }
}

// MARK: - Emote Bar

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
