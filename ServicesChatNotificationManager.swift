//
//  ChatNotificationManager.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/23/26.
//

import Foundation
import CloudKit
import UserNotifications

/// Represents a pending in-app banner notification for a chat message
struct ChatBannerNotification: Identifiable, Equatable {
    let id = UUID()
    let senderUsername: String
    let content: String
    let chatType: ChatType
    let chatIdentifier: String // gameRecordName or groupChatID
    let timestamp: Date
    
    enum ChatType {
        case game
        case group
    }
    
    static func == (lhs: ChatBannerNotification, rhs: ChatBannerNotification) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages CloudKit chat subscriptions, in-app banner notifications, and push notification handling
@Observable
@MainActor
class ChatNotificationManager {
    static let shared = ChatNotificationManager()
    
    // MARK: - In-App Banner State
    
    /// The currently visible banner notification (nil = hidden)
    var currentBanner: ChatBannerNotification?
    
    // MARK: - Active Chat Tracking
    
    /// The game chat the user is currently viewing (suppress banners for this chat)
    var activeGameChatRecordName: String?
    
    /// The group chat the user is currently viewing (suppress banners for this chat)
    var activeGroupChatID: String?
    
    // MARK: - Private State
    
    private var bannerQueue: [ChatBannerNotification] = []
    private var activeSubscriptionIDs: Set<String> = []
    private var dismissTask: Task<Void, Never>?
    
    private let cloudKit = CloudKitService.shared
    private let container = CKContainer(identifier: "iCloud.com.bejaflor.Kosudoku")
    
    private init() {}
    
    // MARK: - Permission
    
    /// Request user notification permission for visible push alerts
    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print(granted ? "✅ Notification permission granted" : "⚠️ Notification permission denied")
        } catch {
            print("⚠️ Failed to request notification permission: \(error)")
        }
    }
    
    // MARK: - CloudKit Subscriptions
    
    /// Subscribe to chat messages for a specific game session
    func subscribeToGameChat(gameRecordName: String) async {
        let subscriptionID = "chat-game-\(gameRecordName)"
        guard !activeSubscriptionIDs.contains(subscriptionID) else { return }
        
        do {
            let gameRecordID = CKRecord.ID(recordName: gameRecordName)
            let reference = CKRecord.Reference(recordID: gameRecordID, action: .none)
            let predicate = NSPredicate(format: "gameSession == %@", reference)
            
            let subscription = CKQuerySubscription(
                recordType: "ChatMessage",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation]
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            notificationInfo.alertBody = "New chat message"
            notificationInfo.soundName = "default"
            notificationInfo.desiredKeys = ["senderRecordName", "senderUsername", "content"]
            subscription.notificationInfo = notificationInfo
            
            _ = try await container.publicCloudDatabase.save(subscription)
            activeSubscriptionIDs.insert(subscriptionID)
            print("✅ Subscribed to game chat: \(gameRecordName)")
        } catch {
            print("⚠️ Failed to subscribe to game chat: \(error.localizedDescription)")
        }
    }
    
    /// Subscribe to chat messages for a specific group chat
    func subscribeToGroupChat(groupChatID: String) async {
        let subscriptionID = "chat-group-\(groupChatID)"
        guard !activeSubscriptionIDs.contains(subscriptionID) else { return }
        
        do {
            let predicate = NSPredicate(format: "groupChatID == %@", groupChatID)
            
            let subscription = CKQuerySubscription(
                recordType: "ChatMessage",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation]
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            notificationInfo.alertBody = "New chat message"
            notificationInfo.soundName = "default"
            notificationInfo.desiredKeys = ["senderRecordName", "senderUsername", "content"]
            subscription.notificationInfo = notificationInfo
            
            _ = try await container.publicCloudDatabase.save(subscription)
            activeSubscriptionIDs.insert(subscriptionID)
            print("✅ Subscribed to group chat: \(groupChatID)")
        } catch {
            print("⚠️ Failed to subscribe to group chat: \(error.localizedDescription)")
        }
    }
    
    /// Unsubscribe from a specific chat
    func unsubscribeFromChat(subscriptionID: String) async {
        guard activeSubscriptionIDs.contains(subscriptionID) else { return }
        do {
            try await container.publicCloudDatabase.deleteSubscription(withID: subscriptionID)
            activeSubscriptionIDs.remove(subscriptionID)
        } catch {
            print("⚠️ Failed to unsubscribe from \(subscriptionID): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Handling Incoming Notifications
    
    /// Process a CloudKit remote notification. Returns true if the notification was handled.
    func handleNotification(userInfo: [String: Any]) async -> Bool {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        guard let queryNotification = notification as? CKQueryNotification else {
            return false
        }
        
        // Extract message fields from the push payload
        let fields = queryNotification.recordFields ?? [:]
        let senderRecordName = fields["senderRecordName"] as? String
        let senderUsername = fields["senderUsername"] as? String ?? "Someone"
        let content = fields["content"] as? String ?? "New message"
        
        // Skip notifications for the current user's own messages
        if let sender = senderRecordName, sender == cloudKit.currentUserRecordName {
            return true
        }
        
        // Determine chat type and identifier from subscription ID
        let subscriptionID = queryNotification.subscriptionID ?? ""
        let chatType: ChatBannerNotification.ChatType
        let chatIdentifier: String
        
        if subscriptionID.hasPrefix("chat-game-") {
            chatType = .game
            chatIdentifier = String(subscriptionID.dropFirst("chat-game-".count))
            // Skip if user is currently viewing this game chat
            if activeGameChatRecordName == chatIdentifier { return true }
        } else if subscriptionID.hasPrefix("chat-group-") {
            chatType = .group
            chatIdentifier = String(subscriptionID.dropFirst("chat-group-".count))
            // Skip if user is currently viewing this group chat
            if activeGroupChatID == chatIdentifier { return true }
        } else {
            return false
        }
        
        let banner = ChatBannerNotification(
            senderUsername: senderUsername,
            content: content,
            chatType: chatType,
            chatIdentifier: chatIdentifier,
            timestamp: Date()
        )
        
        showBanner(banner)
        return true
    }
    
    // MARK: - Banner Display
    
    private func showBanner(_ banner: ChatBannerNotification) {
        if currentBanner != nil {
            bannerQueue.append(banner)
        } else {
            currentBanner = banner
            scheduleAutoDismiss()
        }
    }
    
    func dismissCurrentBanner() {
        dismissTask?.cancel()
        dismissTask = nil
        currentBanner = nil
        
        // Show next queued banner after a short delay
        if !bannerQueue.isEmpty {
            let next = bannerQueue.removeFirst()
            dismissTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                currentBanner = next
                scheduleAutoDismiss()
            }
        }
    }
    
    private func scheduleAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            dismissCurrentBanner()
        }
    }
}
