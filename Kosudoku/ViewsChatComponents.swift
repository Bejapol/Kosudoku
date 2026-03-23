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
    @State private var cloudKitService = CloudKitService.shared
    
    // Static cache so profile photos persist across view recreations during polling
    private static var photoCache: [String: Data] = [:]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isCurrentUser {
                // Other user's photo on left
                ProfilePhotoView(
                    imageData: profileImageData,
                    displayName: message.senderUsername,
                    size: 32
                )
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderUsername)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                // Current user's photo on right
                ProfilePhotoView(
                    imageData: profileImageData,
                    displayName: message.senderUsername,
                    size: 32
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        .task {
            await loadProfilePhoto()
        }
    }
    
    // Fetch profile photo from CloudKit, using a static cache to avoid refetching
    private func loadProfilePhoto() async {
        // Check static cache first
        if let cached = Self.photoCache[message.senderRecordName] {
            if profileImageData == nil {
                profileImageData = cached
            }
            return
        }
        
        // If it's the current user, use their local profile
        if isCurrentUser, let currentProfile = cloudKitService.currentUserProfile {
            profileImageData = currentProfile.avatarImageData
            if let data = currentProfile.avatarImageData {
                Self.photoCache[message.senderRecordName] = data
            }
            return
        }
        
        // For other users, look up by ownerRecordName (the iCloud user record name)
        do {
            if let profile = try await cloudKitService.fetchUserProfileByOwner(ownerRecordName: message.senderRecordName) {
                profileImageData = profile.avatarImageData
                if let data = profile.avatarImageData {
                    Self.photoCache[message.senderRecordName] = data
                }
            }
        } catch {
            print("Failed to load profile photo for \(message.senderUsername): \(error)")
        }
    }
}
