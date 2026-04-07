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

/// Full-screen animated emote overlay — emoji scales up, floats upward, and fades out.
/// Always present in the view hierarchy (not conditional) for reliable animation triggering.
struct EmoteAnimationOverlay: View {
    @Binding var emoteEvent: EmoteEvent?
    
    // The event currently being animated (captured so we can display it during fade-out)
    @State private var displayedEvent: EmoteEvent?
    @State private var scale: CGFloat = 0
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var animationWorkItem: DispatchWorkItem?
    
    var body: some View {
        ZStack {
            if let event = displayedEvent {
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
                .scaleEffect(scale)
                .offset(y: yOffset)
                .opacity(opacity)
                .transition(.identity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: emoteEvent?.id) { _, newID in
            guard newID != nil, let event = emoteEvent else { return }
            startAnimation(for: event)
        }
    }
    
    private func startAnimation(for event: EmoteEvent) {
        // Cancel any in-flight animation
        animationWorkItem?.cancel()
        
        // Reset to initial state immediately (no animation)
        scale = 0.2
        yOffset = 0
        opacity = 0
        displayedEvent = event
        
        // Phase 1: Spring scale in + fade in (next run loop so SwiftUI picks up the reset)
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Phase 2: Float up and fade out after the scale-in settles
            withAnimation(.easeInOut(duration: 1.5).delay(0.5)) {
                yOffset = -120
                opacity = 0
            }
        }
        
        // Phase 3: Cleanup after animation completes
        let workItem = DispatchWorkItem { [self] in
            displayedEvent = nil
            scale = 0
            yOffset = 0
            opacity = 0
            emoteEvent = nil
        }
        animationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: workItem)
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
