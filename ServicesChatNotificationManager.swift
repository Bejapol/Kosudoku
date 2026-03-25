//
//  ChatNotificationManager.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/23/26.
//

import Foundation
import CloudKit
import UserNotifications

/// Represents a pending in-app banner notification
struct ChatBannerNotification: Identifiable, Equatable {
    let id = UUID()
    let senderUsername: String
    let content: String
    let bannerType: BannerType
    let chatIdentifier: String // gameRecordName, groupChatID, or friendshipRecordName
    let timestamp: Date
    
    enum BannerType {
        case gameChat
        case groupChat
        case friendRequest
        case gameInvite
    }
    
    static func == (lhs: ChatBannerNotification, rhs: ChatBannerNotification) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages CloudKit chat subscriptions, in-app banner notifications, and push notification handling.
///
/// In-app banners work via two mechanisms:
/// 1. **Polling-based**: Chat views report new messages via `checkForNewMessages`, which is the
///    primary mechanism for in-app banners (reliable, works on simulator and device).
/// 2. **Push-based**: CloudKit subscriptions deliver background push notifications so the user
///    sees system alerts when the app isn't in the foreground.
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
    
    /// Tracks message stable IDs we've already seen to avoid showing duplicate banners
    private var seenMessageIDs: Set<String> = []
    
    /// Tracks friend request record names we've already seen
    private var seenFriendRequestIDs: Set<String> = []
    
    /// Tracks game invite record names we've already seen
    private var seenGameInviteIDs: Set<String> = []
    
    private let cloudKit = CloudKitService.shared
    private let container = CKContainer(identifier: "iCloud.com.bejaflor.Kosudoku")
    
    /// Tracks which chats are being polled for new messages
    private var monitoredGameChats: Set<String> = []
    private var monitoredGroupChats: Set<String> = []
    private var pollTask: Task<Void, Never>?
    
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
    
    // MARK: - Polling-Based New Message Detection
    
    /// Called by chat views when they detect new messages from other users during polling.
    /// This is the primary mechanism for in-app banners.
    func checkForNewMessages(
        _ messages: [(senderRecordName: String, senderUsername: String, content: String, stableID: String)],
        bannerType: ChatBannerNotification.BannerType,
        chatIdentifier: String
    ) {
        let currentUser = cloudKit.currentUserRecordName
        
        // Skip if the user is currently viewing this chat
        switch bannerType {
        case .gameChat:
            if activeGameChatRecordName == chatIdentifier { return }
        case .groupChat:
            if activeGroupChatID == chatIdentifier { return }
        case .friendRequest, .gameInvite:
            break
        }
        
        for msg in messages {
            // Skip own messages
            if msg.senderRecordName == currentUser { continue }
            
            // Skip already-seen messages
            guard seenMessageIDs.insert(msg.stableID).inserted else { continue }
            
            let banner = ChatBannerNotification(
                senderUsername: msg.senderUsername,
                content: msg.content,
                bannerType: bannerType,
                chatIdentifier: chatIdentifier,
                timestamp: Date()
            )
            showBanner(banner)
        }
    }
    
    /// Register messages as "seen" so they don't trigger future banners.
    /// Call this when initially loading a chat's messages.
    func markMessagesSeen(_ stableIDs: [String]) {
        seenMessageIDs.formUnion(stableIDs)
    }
    
    /// Mark existing friend requests as seen so they don't trigger banners on launch.
    func markFriendRequestsSeen(_ recordNames: [String]) {
        seenFriendRequestIDs.formUnion(recordNames)
    }
    
    /// Mark existing game invites as seen so they don't trigger banners on launch.
    func markGameInvitesSeen(_ recordNames: [String]) {
        seenGameInviteIDs.formUnion(recordNames)
    }
    
    // MARK: - Background Polling for In-App Banners
    
    /// Register a game chat to be monitored for new messages
    func monitorGameChat(gameRecordName: String) {
        monitoredGameChats.insert(gameRecordName)
        startPollingIfNeeded()
    }
    
    /// Register a group chat to be monitored for new messages
    func monitorGroupChat(groupChatID: String) {
        monitoredGroupChats.insert(groupChatID)
        startPollingIfNeeded()
    }
    
    /// Start the background poll loop if not already running
    private func startPollingIfNeeded() {
        guard pollTask == nil else { return }
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await pollForNewMessages()
            }
        }
    }
    
    /// Stop polling (e.g. when all chats are unmonitored)
    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
    
    /// Poll CloudKit for new messages in all monitored chats
    private func pollForNewMessages() async {
        let currentUser = cloudKit.currentUserRecordName
        
        // Poll game chats
        for gameRecordName in monitoredGameChats {
            // Skip if user is viewing this chat (it has its own polling)
            if activeGameChatRecordName == gameRecordName { continue }
            
            do {
                let records = try await cloudKit.fetchChatMessages(gameRecordName: gameRecordName, limit: 5)
                var newMessages: [(senderRecordName: String, senderUsername: String, content: String, stableID: String)] = []
                
                for record in records {
                    guard let sender = record["senderRecordName"] as? String,
                          let username = record["senderUsername"] as? String,
                          let content = record["content"] as? String else { continue }
                    let timestamp = (record["timestamp"] as? Date) ?? Date()
                    let stableID = "\(sender)|\(content)|\(Int(timestamp.timeIntervalSince1970))"
                    
                    if sender != currentUser && !seenMessageIDs.contains(stableID) {
                        newMessages.append((sender, username, content, stableID))
                    }
                }
                
                if !newMessages.isEmpty {
                    checkForNewMessages(newMessages, bannerType: .gameChat, chatIdentifier: gameRecordName)
                }
            } catch {
                // Non-critical, will retry next cycle
            }
        }
        
        // Poll group chats
        for groupChatID in monitoredGroupChats {
            if activeGroupChatID == groupChatID { continue }
            
            do {
                let records = try await cloudKit.fetchChatMessages(groupChatID: groupChatID, limit: 5)
                var newMessages: [(senderRecordName: String, senderUsername: String, content: String, stableID: String)] = []
                
                for record in records {
                    guard let sender = record["senderRecordName"] as? String,
                          let username = record["senderUsername"] as? String,
                          let content = record["content"] as? String else { continue }
                    let timestamp = (record["timestamp"] as? Date) ?? Date()
                    let stableID = "\(sender)|\(content)|\(Int(timestamp.timeIntervalSince1970))"
                    
                    if sender != currentUser && !seenMessageIDs.contains(stableID) {
                        newMessages.append((sender, username, content, stableID))
                    }
                }
                
                if !newMessages.isEmpty {
                    checkForNewMessages(newMessages, bannerType: .groupChat, chatIdentifier: groupChatID)
                }
            } catch {
                // Non-critical
            }
        }
        
        // Poll for new friend requests
        await pollForFriendRequests()
        
        // Poll for new game invites
        await pollForGameInvites()
    }
    
    /// Poll CloudKit for new pending friend requests directed at the current user
    private func pollForFriendRequests() async {
        guard let currentUser = cloudKit.currentUserRecordName else { return }
        
        do {
            let predicate = NSPredicate(format: "friendRecordName == %@ AND status == %@",
                                        currentUser, "pending")
            let query = CKQuery(recordType: "Friendship", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            
            let (matchResults, _) = try await container.publicCloudDatabase.records(
                matching: query, desiredKeys: ["userRecordName", "userUsername", "userDisplayName"],
                resultsLimit: 5
            )
            
            for (_, result) in matchResults {
                guard let record = try? result.get() else { continue }
                let recordName = record.recordID.recordName
                
                guard seenFriendRequestIDs.insert(recordName).inserted else { continue }
                
                let senderUsername = (record["userUsername"] as? String)
                    ?? (record["userDisplayName"] as? String)
                    ?? "Someone"
                
                let banner = ChatBannerNotification(
                    senderUsername: senderUsername,
                    content: "sent you a friend request",
                    bannerType: .friendRequest,
                    chatIdentifier: recordName,
                    timestamp: Date()
                )
                showBanner(banner)
            }
        } catch {
            // Non-critical
        }
    }
    
    /// Poll CloudKit for new game invitations for the current user
    private func pollForGameInvites() async {
        guard let currentUser = cloudKit.currentUserRecordName else { return }
        
        do {
            let predicate = NSPredicate(format: "invitedPlayers CONTAINS %@ AND status == %@",
                                        currentUser, "waiting")
            let query = CKQuery(recordType: "GameSession", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            
            let (matchResults, _) = try await container.publicCloudDatabase.records(
                matching: query, desiredKeys: ["hostRecordName", "difficulty"],
                resultsLimit: 5
            )
            
            for (_, result) in matchResults {
                guard let record = try? result.get() else { continue }
                let recordName = record.recordID.recordName
                
                guard seenGameInviteIDs.insert(recordName).inserted else { continue }
                
                let difficulty = (record["difficulty"] as? String)?.capitalized ?? "a"
                
                // Look up host username
                var hostUsername = "Someone"
                if let hostRecordName = record["hostRecordName"] as? String,
                   let profile = try? await cloudKit.fetchUserProfileByOwner(ownerRecordName: hostRecordName) {
                    hostUsername = profile.username
                }
                
                let banner = ChatBannerNotification(
                    senderUsername: hostUsername,
                    content: "invited you to a \(difficulty) game",
                    bannerType: .gameInvite,
                    chatIdentifier: recordName,
                    timestamp: Date()
                )
                showBanner(banner)
            }
        } catch {
            // Non-critical
        }
    }
    
    // MARK: - CloudKit Subscriptions (for background push)
    
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
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription already exists on server — that's fine, just track it locally
            activeSubscriptionIDs.insert(subscriptionID)
            print("ℹ️ Game chat subscription already exists: \(gameRecordName)")
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
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription already exists on server — that's fine
            activeSubscriptionIDs.insert(subscriptionID)
            print("ℹ️ Group chat subscription already exists: \(groupChatID)")
        } catch {
            print("⚠️ Failed to subscribe to group chat: \(error.localizedDescription)")
        }
    }
    
    /// Subscribe to new friend requests directed at the current user
    func subscribeToFriendRequests() async {
        guard let currentUser = cloudKit.currentUserRecordName else { return }
        let subscriptionID = "friend-request-\(currentUser)"
        guard !activeSubscriptionIDs.contains(subscriptionID) else { return }
        
        do {
            let predicate = NSPredicate(format: "friendRecordName == %@ AND status == %@",
                                        currentUser, "pending")
            
            let subscription = CKQuerySubscription(
                recordType: "Friendship",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation]
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            notificationInfo.alertBody = "New friend request"
            notificationInfo.soundName = "default"
            notificationInfo.desiredKeys = ["userRecordName", "userUsername", "userDisplayName"]
            subscription.notificationInfo = notificationInfo
            
            _ = try await container.publicCloudDatabase.save(subscription)
            activeSubscriptionIDs.insert(subscriptionID)
            print("✅ Subscribed to friend requests")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            activeSubscriptionIDs.insert(subscriptionID)
            print("ℹ️ Friend request subscription already exists")
        } catch {
            print("⚠️ Failed to subscribe to friend requests: \(error.localizedDescription)")
        }
    }
    
    /// Subscribe to new game invitations for the current user
    func subscribeToGameInvites() async {
        guard let currentUser = cloudKit.currentUserRecordName else { return }
        let subscriptionID = "game-invite-\(currentUser)"
        guard !activeSubscriptionIDs.contains(subscriptionID) else { return }
        
        do {
            let predicate = NSPredicate(format: "invitedPlayers CONTAINS %@ AND status == %@",
                                        currentUser, "waiting")
            
            let subscription = CKQuerySubscription(
                recordType: "GameSession",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation]
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            notificationInfo.alertBody = "New game invitation"
            notificationInfo.soundName = "default"
            notificationInfo.desiredKeys = ["hostRecordName", "difficulty"]
            subscription.notificationInfo = notificationInfo
            
            _ = try await container.publicCloudDatabase.save(subscription)
            activeSubscriptionIDs.insert(subscriptionID)
            print("✅ Subscribed to game invites")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            activeSubscriptionIDs.insert(subscriptionID)
            print("ℹ️ Game invite subscription already exists")
        } catch {
            print("⚠️ Failed to subscribe to game invites: \(error.localizedDescription)")
        }
    }
    
    /// Unsubscribe from a specific chat
    func unsubscribeFromChat(subscriptionID: String) async {
        activeSubscriptionIDs.remove(subscriptionID)
        do {
            try await container.publicCloudDatabase.deleteSubscription(withID: subscriptionID)
        } catch {
            // Not critical — subscription may already be gone
            print("⚠️ Failed to unsubscribe from \(subscriptionID): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Handling Incoming Push Notifications
    
    /// Process a CloudKit remote notification. Returns true if the notification was handled.
    func handleNotification(userInfo: [String: Any]) async -> Bool {
        // Try to parse as a CloudKit notification
        guard let ckDict = userInfo["ck"] as? [String: Any],
              let qryDict = ckDict["qry"] as? [String: Any] else {
            // Fallback: try the deprecated API
            return handleNotificationLegacy(userInfo: userInfo)
        }
        
        // Extract subscription ID
        guard let subscriptionID = qryDict["sid"] as? String else {
            return false
        }
        
        // Extract fields from "af" (alert fields) if present
        let alertFields = qryDict["af"] as? [String: Any] ?? [:]
        let senderRecordName = alertFields["senderRecordName"] as? String
        let senderUsername = alertFields["senderUsername"] as? String ?? "Someone"
        let content = alertFields["content"] as? String ?? "New message"
        
        // Skip own messages
        if let sender = senderRecordName, sender == cloudKit.currentUserRecordName {
            return true
        }
        
        // Determine banner type from subscription ID
        let bannerType: ChatBannerNotification.BannerType
        let chatIdentifier: String
        
        if subscriptionID.hasPrefix("chat-game-") {
            bannerType = .gameChat
            chatIdentifier = String(subscriptionID.dropFirst("chat-game-".count))
            if activeGameChatRecordName == chatIdentifier { return true }
        } else if subscriptionID.hasPrefix("chat-group-") {
            bannerType = .groupChat
            chatIdentifier = String(subscriptionID.dropFirst("chat-group-".count))
            if activeGroupChatID == chatIdentifier { return true }
        } else if subscriptionID.hasPrefix("friend-request-") {
            bannerType = .friendRequest
            chatIdentifier = String(subscriptionID.dropFirst("friend-request-".count))
        } else if subscriptionID.hasPrefix("game-invite-") {
            bannerType = .gameInvite
            chatIdentifier = String(subscriptionID.dropFirst("game-invite-".count))
        } else {
            return false
        }
        
        let banner = ChatBannerNotification(
            senderUsername: senderUsername,
            content: content,
            bannerType: bannerType,
            chatIdentifier: chatIdentifier,
            timestamp: Date()
        )
        
        showBanner(banner)
        return true
    }
    
    /// Fallback using deprecated CKNotification API for older notification formats
    private func handleNotificationLegacy(userInfo: [String: Any]) -> Bool {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        guard let queryNotification = notification as? CKQueryNotification else {
            return false
        }
        
        let fields = queryNotification.recordFields ?? [:]
        let senderRecordName = fields["senderRecordName"] as? String
        let senderUsername = fields["senderUsername"] as? String ?? "Someone"
        let content = fields["content"] as? String ?? "New message"
        
        if let sender = senderRecordName, sender == cloudKit.currentUserRecordName {
            return true
        }
        
        let subscriptionID = queryNotification.subscriptionID ?? ""
        let bannerType: ChatBannerNotification.BannerType
        let chatIdentifier: String
        
        if subscriptionID.hasPrefix("chat-game-") {
            bannerType = .gameChat
            chatIdentifier = String(subscriptionID.dropFirst("chat-game-".count))
            if activeGameChatRecordName == chatIdentifier { return true }
        } else if subscriptionID.hasPrefix("chat-group-") {
            bannerType = .groupChat
            chatIdentifier = String(subscriptionID.dropFirst("chat-group-".count))
            if activeGroupChatID == chatIdentifier { return true }
        } else if subscriptionID.hasPrefix("friend-request-") {
            bannerType = .friendRequest
            chatIdentifier = String(subscriptionID.dropFirst("friend-request-".count))
        } else if subscriptionID.hasPrefix("game-invite-") {
            bannerType = .gameInvite
            chatIdentifier = String(subscriptionID.dropFirst("game-invite-".count))
        } else {
            return false
        }
        
        let banner = ChatBannerNotification(
            senderUsername: senderUsername,
            content: content,
            bannerType: bannerType,
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
