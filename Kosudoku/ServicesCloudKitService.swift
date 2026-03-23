//
//  CloudKitService.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation
import CloudKit
import SwiftUI

/// Service for managing CloudKit operations
@Observable
class CloudKitService {
    static let shared = CloudKitService()
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    
    // Current user information
    var currentUserRecordName: String?
    var currentUserProfile: UserProfile?
    var isAuthenticated = false
    var isSignedOut = false  // Prevents auto-reload of profile after sign out
    
    // Record types
    enum RecordType: String {
        case userProfile = "UserProfile"
        case gameSession = "GameSession"
        case playerGameState = "PlayerGameState"
        case chatMessage = "ChatMessage"
        case friendship = "Friendship"
        case groupChat = "GroupChat"
    }
    
    private init() {
        // Use the correct CloudKit container identifier
        // Note: Change this to match your actual container ID
        self.container = CKContainer(identifier: "iCloud.com.bejaflor.Kosudoku")
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
        
        print("📱 CloudKit container: \(container.containerIdentifier ?? "unknown")")
    }
    
    // MARK: - Authentication
    
    /// Fetch the current user's CloudKit record ID
    func authenticateUser() async throws {
        print("🔐 Authenticating user...")
        do {
            let recordID = try await container.userRecordID()
            currentUserRecordName = recordID.recordName
            isAuthenticated = true
            print("✅ User authenticated: \(recordID.recordName)")
        } catch {
            print("❌ Authentication failed: \(error)")
            throw error
        }
    }
    
    /// Request CloudKit permissions
    func requestPermissions() async throws {
        print("🔐 Requesting CloudKit permissions...")
        let status = try await container.accountStatus()
        print("📱 Account status: \(status.rawValue)")
        
        switch status {
        case .available:
            isAuthenticated = true
            print("✅ iCloud account available")
        case .noAccount:
            print("❌ No iCloud account")
            throw CloudKitError.noAccount
        case .restricted:
            print("❌ iCloud account restricted")
            throw CloudKitError.restricted
        case .couldNotDetermine:
            print("❌ Could not determine iCloud status")
            throw CloudKitError.couldNotDetermine
        case .temporarilyUnavailable:
            print("❌ iCloud temporarily unavailable")
            throw CloudKitError.temporarilyUnavailable
        @unknown default:
            print("❌ Unknown iCloud status")
            throw CloudKitError.unknown
        }
    }
    
    // MARK: - User Profile Operations
    
    /// Create or update user profile
    func saveUserProfile(_ profile: UserProfile) async throws {
        let record: CKRecord
        
        if let recordName = profile.cloudKitRecordName {
            // Fetch the existing record so CloudKit can resolve change tokens
            let recordID = CKRecord.ID(recordName: recordName)
            record = try await publicDatabase.record(for: recordID)
        } else {
            record = CKRecord(recordType: RecordType.userProfile.rawValue)
        }
        
        record["username"] = profile.username
        record["displayName"] = profile.displayName
        record["totalScore"] = profile.totalScore
        record["gamesPlayed"] = profile.gamesPlayed
        record["gamesWon"] = profile.gamesWon
        // Store the iCloud user record name so other users can identify the owner
        if let userRecordName = currentUserRecordName {
            record["ownerRecordName"] = userRecordName
        }
        
        if let avatarData = profile.avatarImageData {
            // Save avatar as asset
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try avatarData.write(to: tempURL)
            record["avatar"] = CKAsset(fileURL: tempURL)
        }
        
        let savedRecord = try await publicDatabase.save(record)
        profile.cloudKitRecordName = savedRecord.recordID.recordName
    }
    
    /// Fetch user profile by record name
    func fetchUserProfile(recordName: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName)
        return try await publicDatabase.record(for: recordID)
    }
    
    /// Fetch user profile as UserProfile object with avatar data
    func fetchUserProfileObject(recordName: String) async throws -> UserProfile? {
        let record = try await fetchUserProfile(recordName: recordName)
        
        guard let username = record["username"] as? String,
              let displayName = record["displayName"] as? String else {
            return nil
        }
        
        let profile = UserProfile(
            username: username,
            displayName: displayName,
            cloudKitRecordName: recordName
        )
        
        profile.totalScore = (record["totalScore"] as? Int) ?? 0
        profile.gamesPlayed = (record["gamesPlayed"] as? Int) ?? 0
        profile.gamesWon = (record["gamesWon"] as? Int) ?? 0
        
        // Load avatar image if available
        if let avatarAsset = record["avatar"] as? CKAsset,
           let avatarURL = avatarAsset.fileURL,
           let avatarData = try? Data(contentsOf: avatarURL) {
            profile.avatarImageData = avatarData
        }
        
        return profile
    }
    
    /// Fetch a user profile by the owner's iCloud user record name.
    /// This queries the `ownerRecordName` field, which maps a UserProfile
    /// to its iCloud user, unlike `fetchUserProfile(recordName:)` which
    /// looks up by the UserProfile record's own CloudKit record ID.
    func fetchUserProfileByOwner(ownerRecordName: String) async throws -> UserProfile? {
        let predicate = NSPredicate(format: "ownerRecordName == %@", ownerRecordName)
        let query = CKQuery(recordType: RecordType.userProfile.rawValue, predicate: predicate)
        let (matchResults, _) = try await publicDatabase.records(matching: query, resultsLimit: 1)
        
        guard let (_, result) = matchResults.first,
              let record = try? result.get() else {
            return nil
        }
        
        guard let username = record["username"] as? String,
              let displayName = record["displayName"] as? String else {
            return nil
        }
        
        let profile = UserProfile(
            username: username,
            displayName: displayName,
            cloudKitRecordName: record.recordID.recordName
        )
        
        profile.totalScore = (record["totalScore"] as? Int) ?? 0
        profile.gamesPlayed = (record["gamesPlayed"] as? Int) ?? 0
        profile.gamesWon = (record["gamesWon"] as? Int) ?? 0
        
        if let avatarAsset = record["avatar"] as? CKAsset,
           let avatarURL = avatarAsset.fileURL,
           let avatarData = try? Data(contentsOf: avatarURL) {
            profile.avatarImageData = avatarData
        }
        
        return profile
    }
    
    /// Search for users by username or display name
    /// CloudKit does not support case-insensitive BEGINSWITH, so we query
    /// with multiple casing variants to approximate case-insensitive search.
    func searchUsers(username: String) async throws -> [CKRecord] {
        let searchVariants = Set([
            username,
            username.lowercased(),
            username.capitalized,
            username.uppercased()
        ])
        
        var seen = Set<CKRecord.ID>()
        var combined: [CKRecord] = []
        
        for variant in searchVariants {
            // Search by username
            let usernamePredicate = NSPredicate(format: "username BEGINSWITH %@", variant)
            let usernameQuery = CKQuery(recordType: RecordType.userProfile.rawValue, predicate: usernamePredicate)
            if let (results, _) = try? await publicDatabase.records(matching: usernameQuery) {
                for (_, result) in results {
                    if let record = try? result.get(), seen.insert(record.recordID).inserted {
                        combined.append(record)
                    }
                }
            }
            
            // Search by display name
            let displayNamePredicate = NSPredicate(format: "displayName BEGINSWITH %@", variant)
            let displayNameQuery = CKQuery(recordType: RecordType.userProfile.rawValue, predicate: displayNamePredicate)
            if let (results, _) = try? await publicDatabase.records(matching: displayNameQuery) {
                for (_, result) in results {
                    if let record = try? result.get(), seen.insert(record.recordID).inserted {
                        combined.append(record)
                    }
                }
            }
        }
        
        return combined
    }
    
    // MARK: - Game Session Operations
    
    /// Create a new game session
    func createGameSession(_ session: GameSession) async throws {
        print("☁️ Creating game session in CloudKit...")
        print("   Host: \(session.hostRecordName)")
        print("   Difficulty: \(session.difficulty.rawValue)")
        
        let record = CKRecord(recordType: RecordType.gameSession.rawValue)
        
        record["hostRecordName"] = session.hostRecordName
        record["difficulty"] = session.difficulty.rawValue
        record["puzzleData"] = session.puzzleData
        record["solutionData"] = session.solutionData
        record["status"] = session.status.rawValue
        record["createdAt"] = session.createdAt
        record["invitedPlayers"] = session.invitedPlayers as CKRecordValue
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            session.cloudKitRecordName = savedRecord.recordID.recordName
            print("✅ Game session saved to CloudKit: \(savedRecord.recordID.recordName)")
        } catch {
            print("❌ Failed to save game session to CloudKit: \(error)")
            if let ckError = error as? CKError {
                print("   CKError code: \(ckError.code.rawValue)")
                print("   CKError description: \(ckError.localizedDescription)")
            }
            throw error
        }
    }
    
    /// Update game session
    func updateGameSession(_ session: GameSession) async throws {
        guard let recordName = session.cloudKitRecordName else {
            throw CloudKitError.noRecordName
        }
        
        let recordID = CKRecord.ID(recordName: recordName)
        let record = try await publicDatabase.record(for: recordID)
        
        record["status"] = session.status.rawValue
        record["puzzleData"] = session.puzzleData
        if let startedAt = session.startedAt {
            record["startedAt"] = startedAt
        }
        if let completedAt = session.completedAt {
            record["completedAt"] = completedAt
        }
        
        _ = try await publicDatabase.save(record)
    }
    
    /// Delete completed/abandoned game sessions (and their cascading PlayerGameState records)
    /// that are older than the specified age
    func cleanupOldGameRecords(olderThan maxAge: TimeInterval = 86400) async {
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        // Clean up completed games older than cutoff
        for status in [GameStatus.completed, GameStatus.abandoned] {
            let predicate = NSPredicate(format: "status == %@ AND createdAt < %@",
                                        status.rawValue, cutoffDate as NSDate)
            let query = CKQuery(recordType: RecordType.gameSession.rawValue, predicate: predicate)
            
            do {
                let (matchResults, _) = try await publicDatabase.records(matching: query)
                let recordIDs = matchResults.compactMap { _, result in
                    try? result.get().recordID
                }
                
                for recordID in recordIDs {
                    _ = try? await publicDatabase.deleteRecord(withID: recordID)
                }
                
                if !recordIDs.isEmpty {
                    print("🧹 Cleaned up \(recordIDs.count) old \(status.rawValue) game records from CloudKit")
                }
            } catch {
                print("⚠️ Failed to cleanup old \(status.rawValue) games: \(error.localizedDescription)")
            }
        }
    }
    
    /// Fetch active game sessions
    func fetchActiveGameSessions() async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "status == %@", GameStatus.active.rawValue)
        let query = CKQuery(recordType: RecordType.gameSession.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let (matchResults, _) = try await publicDatabase.records(matching: query)
        
        return matchResults.compactMap { _, result in
            try? result.get()
        }
    }
    
    /// Fetch game sessions where the current user is an invited player.
    /// CloudKit does not support AND combined with OR in a single predicate,
    /// so we run separate queries for each status and merge the results.
    func fetchInvitedGameSessions() async throws -> [CKRecord] {
        guard let currentUser = currentUserRecordName else {
            throw CloudKitError.notAuthenticated
        }
        
        var seen = Set<CKRecord.ID>()
        var combined: [CKRecord] = []
        
        // Query 1: invited games with "waiting" status
        let waitingPredicate = NSPredicate(format: "invitedPlayers CONTAINS %@ AND status == %@",
                                           currentUser, GameStatus.waiting.rawValue)
        let waitingQuery = CKQuery(recordType: RecordType.gameSession.rawValue, predicate: waitingPredicate)
        waitingQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        if let (results, _) = try? await publicDatabase.records(matching: waitingQuery) {
            for (_, result) in results {
                if let record = try? result.get(), seen.insert(record.recordID).inserted {
                    combined.append(record)
                }
            }
        }
        
        // Query 2: invited games with "active" status
        let activePredicate = NSPredicate(format: "invitedPlayers CONTAINS %@ AND status == %@",
                                          currentUser, GameStatus.active.rawValue)
        let activeQuery = CKQuery(recordType: RecordType.gameSession.rawValue, predicate: activePredicate)
        activeQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        if let (results, _) = try? await publicDatabase.records(matching: activeQuery) {
            for (_, result) in results {
                if let record = try? result.get(), seen.insert(record.recordID).inserted {
                    combined.append(record)
                }
            }
        }
        
        print("🎮 Fetched \(combined.count) invited game sessions from CloudKit")
        return combined
    }
    
    /// Fetch a single game session by record name
    func fetchGameSession(recordName: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName)
        return try await publicDatabase.record(for: recordID)
    }
    
    // MARK: - Player State Operations
    
    /// Save player game state (creates on first call, updates existing on subsequent calls)
    func savePlayerState(_ state: PlayerGameState, gameRecordName: String) async throws {
        let record: CKRecord
        
        if let existingRecordName = state.cloudKitRecordName {
            // Update existing record
            let recordID = CKRecord.ID(recordName: existingRecordName)
            record = try await publicDatabase.record(for: recordID)
        } else {
            // Create new record
            record = CKRecord(recordType: RecordType.playerGameState.rawValue)
            // Set the game session reference only on creation
            let gameRecordID = CKRecord.ID(recordName: gameRecordName)
            record["gameSession"] = CKRecord.Reference(recordID: gameRecordID, action: .deleteSelf)
        }
        
        record["playerRecordName"] = state.playerRecordName
        record["playerUsername"] = state.playerUsername
        record["currentBoardData"] = state.currentBoardData
        record["score"] = state.score
        record["correctGuesses"] = state.correctGuesses
        record["incorrectGuesses"] = state.incorrectGuesses
        record["cellsCompleted"] = state.cellsCompleted
        record["joinedAt"] = state.joinedAt
        if let lastMoveAt = state.lastMoveAt {
            record["lastMoveAt"] = lastMoveAt
        }
        record["selectedRow"] = state.selectedRow as CKRecordValue?
        record["selectedCol"] = state.selectedCol as CKRecordValue?
        
        let savedRecord = try await publicDatabase.save(record)
        state.cloudKitRecordName = savedRecord.recordID.recordName
    }
    
    /// Subscribe to changes in a game session
    /// Note: This requires the 'gameSession' field to be indexed in CloudKit.
    /// If it fails, the app will fall back to polling for updates.
    func subscribeToGameUpdates(gameRecordName: String) async throws {
        do {
            let gameRecordID = CKRecord.ID(recordName: gameRecordName)
            let reference = CKRecord.Reference(recordID: gameRecordID, action: .none)
            let predicate = NSPredicate(format: "gameSession == %@", reference)
            
            let subscription = CKQuerySubscription(
                recordType: RecordType.playerGameState.rawValue,
                predicate: predicate,
                subscriptionID: "game-\(gameRecordName)",
                options: [.firesOnRecordCreation, .firesOnRecordUpdate]
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            _ = try await publicDatabase.save(subscription)
            print("✅ Successfully subscribed to game updates")
        } catch {
            // Subscription failed - likely because gameSession field is not queryable
            // This is not critical, we can poll for updates instead
            print("⚠️ Failed to create subscription (will use polling instead): \(error.localizedDescription)")
            // Don't throw - allow the game to continue without subscriptions
        }
    }
    
    /// Fetch all player states for a game session
    func fetchPlayerStates(gameRecordName: String) async throws -> [CKRecord] {
        let gameRecordID = CKRecord.ID(recordName: gameRecordName)
        let reference = CKRecord.Reference(recordID: gameRecordID, action: .none)
        let predicate = NSPredicate(format: "gameSession == %@", reference)
        let query = CKQuery(recordType: RecordType.playerGameState.rawValue, predicate: predicate)
        
        let (matchResults, _) = try await publicDatabase.records(matching: query)
        
        let records = matchResults.compactMap { _, result in
            try? result.get()
        }
        print("🎮 fetchPlayerStates: found \(records.count) player states for game \(gameRecordName)")
        return records
    }
    
    // MARK: - Group Chat Operations
    
    /// Save a group chat to CloudKit
    func saveGroupChat(_ groupChat: GroupChat) async throws {
        let record: CKRecord
        
        if let existingRecordName = groupChat.cloudKitRecordName {
            let recordID = CKRecord.ID(recordName: existingRecordName)
            record = try await publicDatabase.record(for: recordID)
        } else {
            record = CKRecord(recordType: RecordType.groupChat.rawValue)
        }
        
        record["name"] = groupChat.name
        record["createdAt"] = groupChat.createdAt
        record["creatorRecordName"] = groupChat.creatorRecordName
        record["memberRecordNames"] = groupChat.memberRecordNames as CKRecordValue
        record["groupChatID"] = groupChat.id.uuidString
        
        let savedRecord = try await publicDatabase.save(record)
        groupChat.cloudKitRecordName = savedRecord.recordID.recordName
    }
    
    /// Fetch group chats where the current user is a member or creator
    func fetchGroupChats() async throws -> [CKRecord] {
        guard let currentUser = currentUserRecordName else {
            throw CloudKitError.notAuthenticated
        }
        
        var seen = Set<CKRecord.ID>()
        var combined: [CKRecord] = []
        
        // Query 1: chats where I am a member
        let memberPredicate = NSPredicate(format: "memberRecordNames CONTAINS %@", currentUser)
        let memberQuery = CKQuery(recordType: RecordType.groupChat.rawValue, predicate: memberPredicate)
        memberQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        if let (results, _) = try? await publicDatabase.records(matching: memberQuery) {
            for (_, result) in results {
                if let record = try? result.get(), seen.insert(record.recordID).inserted {
                    combined.append(record)
                }
            }
        }
        
        // Query 2: chats where I am the creator
        let creatorPredicate = NSPredicate(format: "creatorRecordName == %@", currentUser)
        let creatorQuery = CKQuery(recordType: RecordType.groupChat.rawValue, predicate: creatorPredicate)
        creatorQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        if let (results, _) = try? await publicDatabase.records(matching: creatorQuery) {
            for (_, result) in results {
                if let record = try? result.get(), seen.insert(record.recordID).inserted {
                    combined.append(record)
                }
            }
        }
        
        return combined
    }
    
    // MARK: - Chat Operations
    
    /// Send a chat message
    func sendChatMessage(_ message: ChatMessage, gameRecordName: String? = nil, groupChatID: String? = nil) async throws {
        let record = CKRecord(recordType: RecordType.chatMessage.rawValue)
        
        record["senderRecordName"] = message.senderRecordName
        record["senderUsername"] = message.senderUsername
        record["content"] = message.content
        record["messageType"] = message.messageType.rawValue
        record["timestamp"] = message.timestamp
        
        if let gameRecordName = gameRecordName {
            let gameRecordID = CKRecord.ID(recordName: gameRecordName)
            record["gameSession"] = CKRecord.Reference(recordID: gameRecordID, action: .deleteSelf)
        }
        
        if let groupChatID = groupChatID {
            record["groupChatID"] = groupChatID
        }
        
        _ = try await publicDatabase.save(record)
    }
    
    /// Fetch chat messages for a game or group
    func fetchChatMessages(gameRecordName: String? = nil, groupChatID: String? = nil, limit: Int = 50) async throws -> [CKRecord] {
        let predicate: NSPredicate
        
        if let gameRecordName = gameRecordName {
            let gameRecordID = CKRecord.ID(recordName: gameRecordName)
            let reference = CKRecord.Reference(recordID: gameRecordID, action: .none)
            predicate = NSPredicate(format: "gameSession == %@", reference)
        } else if let groupChatID = groupChatID {
            predicate = NSPredicate(format: "groupChatID == %@", groupChatID)
        } else {
            throw CloudKitError.invalidParameters
        }
        
        let query = CKQuery(recordType: RecordType.chatMessage.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        let (matchResults, _) = try await publicDatabase.records(matching: query, desiredKeys: nil, resultsLimit: limit)
        
        return matchResults.compactMap { _, result in
            try? result.get()
        }
    }
    
    // MARK: - Friendship Operations
    
    /// Send friend request, returns the CloudKit record name of the saved record
    @discardableResult
    func sendFriendRequest(to friendRecordName: String, friendUsername: String, friendDisplayName: String) async throws -> String {
        let record = CKRecord(recordType: RecordType.friendship.rawValue)
        
        guard let currentUser = currentUserRecordName,
              let currentProfile = currentUserProfile else {
            throw CloudKitError.notAuthenticated
        }
        
        record["userRecordName"] = currentUser
        record["userUsername"] = currentProfile.username
        record["userDisplayName"] = currentProfile.displayName
        record["friendRecordName"] = friendRecordName
        record["friendUsername"] = friendUsername
        record["friendDisplayName"] = friendDisplayName
        record["status"] = FriendshipStatus.pending.rawValue
        record["createdAt"] = Date()
        
        let savedRecord = try await publicDatabase.save(record)
        return savedRecord.recordID.recordName
    }
    
    /// Fetch friendships for current user
    /// CloudKit does not support OR predicates across different fields,
    /// so we run two separate queries and merge the results.
    func fetchFriendships() async throws -> [CKRecord] {
        guard let currentUser = currentUserRecordName else {
            throw CloudKitError.notAuthenticated
        }
        
        var seen = Set<CKRecord.ID>()
        var combined: [CKRecord] = []
        
        // Query 1: friendships where I am the sender
        let senderPredicate = NSPredicate(format: "userRecordName == %@", currentUser)
        let senderQuery = CKQuery(recordType: RecordType.friendship.rawValue, predicate: senderPredicate)
        let (senderResults, _) = try await publicDatabase.records(matching: senderQuery)
        for (_, result) in senderResults {
            if let record = try? result.get(), seen.insert(record.recordID).inserted {
                combined.append(record)
            }
        }
        
        // Query 2: friendships where I am the recipient
        let recipientPredicate = NSPredicate(format: "friendRecordName == %@", currentUser)
        let recipientQuery = CKQuery(recordType: RecordType.friendship.rawValue, predicate: recipientPredicate)
        let (recipientResults, _) = try await publicDatabase.records(matching: recipientQuery)
        for (_, result) in recipientResults {
            if let record = try? result.get(), seen.insert(record.recordID).inserted {
                combined.append(record)
            }
        }
        
        print("📋 Fetched \(combined.count) friendships from CloudKit (sender: \(senderResults.count), recipient: \(recipientResults.count))")
        return combined
    }
    
    /// Update friendship status in CloudKit by directly modifying the original record.
    /// Requires the Friendship record type to have Write permission for the _world role
    /// in CloudKit Dashboard > Schema > Security Roles.
    func updateFriendshipStatus(cloudKitRecordName: String, status: FriendshipStatus) async throws {
        let recordID = CKRecord.ID(recordName: cloudKitRecordName)
        let record = try await publicDatabase.record(for: recordID)
        
        record["status"] = status.rawValue
        if status == .accepted {
            record["acceptedAt"] = Date()
        }
        
        _ = try await publicDatabase.save(record)
        print("✅ Updated friendship record \(cloudKitRecordName) to \(status.rawValue)")
    }
    
    /// Delete a friendship record from CloudKit
    func deleteFriendship(cloudKitRecordName: String) async throws {
        let recordID = CKRecord.ID(recordName: cloudKitRecordName)
        try await publicDatabase.deleteRecord(withID: recordID)
    }
    
    /// Subscribe to incoming friend requests for the current user
    func subscribeToFriendRequests() async {
        guard let currentUser = currentUserRecordName else { return }
        
        do {
            let predicate = NSPredicate(format: "friendRecordName == %@", currentUser)
            let subscription = CKQuerySubscription(
                recordType: RecordType.friendship.rawValue,
                predicate: predicate,
                subscriptionID: "friend-requests-\(currentUser)",
                options: [.firesOnRecordCreation, .firesOnRecordUpdate]
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.alertBody = "You have a new friend request!"
            notificationInfo.shouldSendContentAvailable = true
            notificationInfo.soundName = "default"
            subscription.notificationInfo = notificationInfo
            
            _ = try await publicDatabase.save(subscription)
            print("✅ Subscribed to friend requests")
        } catch {
            print("⚠️ Failed to subscribe to friend requests: \(error.localizedDescription)")
        }
    }
}

// MARK: - Errors

enum CloudKitError: LocalizedError {
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
    case unknown
    case notAuthenticated
    case noRecordName
    case invalidParameters
    
    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "No iCloud account found. Please sign in to iCloud in Settings."
        case .restricted:
            return "iCloud access is restricted."
        case .couldNotDetermine:
            return "Could not determine iCloud status."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable."
        case .unknown:
            return "An unknown error occurred."
        case .notAuthenticated:
            return "User is not authenticated."
        case .noRecordName:
            return "No CloudKit record name found."
        case .invalidParameters:
            return "Invalid parameters provided."
        }
    }
}
