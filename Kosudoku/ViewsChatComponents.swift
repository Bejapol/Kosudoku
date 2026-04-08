//
//  ChatComponents.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/9/26.
//

import SwiftUI
import SwiftData

/// Shared chat message bubble component with profile photo support
struct ChatMessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    @State private var profileImageData: Data?
    @State private var profileFrame: ProfileFrame?
    @State private var cloudKitService = CloudKitService.shared
    @State private var showingProfile = false
    
    // Static cache so profile data persists across view recreations during polling
    private static var photoCache: [String: Data] = [:]
    private static var frameCache: [String: ProfileFrame] = [:]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isCurrentUser {
                // Other user's photo on left — tappable
                ProfilePhotoView(
                    imageData: profileImageData,
                    displayName: message.senderUsername,
                    size: 32,
                    profileFrame: profileFrame
                )
                .onTapGesture { showingProfile = true }
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderUsername)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .onTapGesture { showingProfile = true }
                }
                
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 250, alignment: isCurrentUser ? .trailing : .leading)
            
            if isCurrentUser {
                // Current user's photo on right — tappable
                ProfilePhotoView(
                    imageData: profileImageData,
                    displayName: message.senderUsername,
                    size: 32,
                    profileFrame: profileFrame
                )
                .onTapGesture { showingProfile = true }
            }
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        .task {
            await loadProfilePhoto()
        }
        .sheet(isPresented: $showingProfile) {
            PlayerProfileView(ownerRecordName: message.senderRecordName)
        }
    }
    
    // Fetch profile photo from CloudKit, using a static cache to avoid refetching
    private func loadProfilePhoto() async {
        // Check static cache first
        if let cached = Self.photoCache[message.senderRecordName] {
            if profileImageData == nil {
                profileImageData = cached
            }
        }
        if let cachedFrame = Self.frameCache[message.senderRecordName] {
            profileFrame = cachedFrame
        }
        if Self.photoCache[message.senderRecordName] != nil {
            return
        }
        
        // If it's the current user, use their local profile
        if isCurrentUser, let currentProfile = cloudKitService.currentUserProfile {
            profileImageData = currentProfile.avatarImageData
            profileFrame = currentProfile.activeProfileFrame
            if let data = currentProfile.avatarImageData {
                Self.photoCache[message.senderRecordName] = data
            }
            Self.frameCache[message.senderRecordName] = currentProfile.activeProfileFrame
            return
        }
        
        // For other users, look up by ownerRecordName (the iCloud user record name)
        do {
            if let profile = try await cloudKitService.fetchUserProfileByOwner(ownerRecordName: message.senderRecordName) {
                profileImageData = profile.avatarImageData
                profileFrame = profile.activeProfileFrame
                if let data = profile.avatarImageData {
                    Self.photoCache[message.senderRecordName] = data
                }
                Self.frameCache[message.senderRecordName] = profile.activeProfileFrame
            }
        } catch {
            print("Failed to load profile photo for \(message.senderUsername): \(error)")
        }
    }
}

/// Renders a .reaction chat message as a large centered emoji bubble
struct EmoteMessageView: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    
    private var emote: GameEmote? {
        GameEmote(rawValue: message.content)
    }
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderUsername)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(emote?.emoji ?? message.content)
                    .font(.system(size: 44))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isCurrentUser { Spacer() }
        }
    }
}
