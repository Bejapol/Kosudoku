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
        // Use your app's CloudKit container with explicit identifier
        // Make sure this matches your entitlements file
        self.container = CKContainer(identifier: "iCloud.com.bejaflor.Kosudoku")
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - Authentication
    
    /// Fetch the current user's CloudKit record ID
    func authenticateUser() async throws {
        let recordID = try await container.userRecordID()
        currentUserRecordName = recordID.recordName
        isAuthenticated = true
    }
    
    /// Request CloudKit permissions
    func requestPermissions() async throws {
        let status = try await container.accountStatus()
        
        switch status {
        case .available:
            isAuthenticated = true
        case .noAccount:
            throw CloudKitError.noAccount
        case .restricted:
            throw CloudKitError.restricted
        case .couldNotDetermine:
            throw CloudKitError.couldNotDetermine
        case .temporarilyUnavailable:
            throw CloudKitError.temporarilyUnavailable
        @unknown default:
            throw CloudKitError.unknown
        }
    }
    
    // MARK: - User Profile Operations
    
    /// Create or update user profile
    func saveUserProfile(_ profile: UserProfile) async throws {
        let record: CKRecord
        
        if let recordName = profile.cloudKitRecordName {
            let recordID = CKRecord.ID(recordName: recordName)
            record = CKRecord(recordType: RecordType.userProfile.rawValue, recordID: recordID)
        } else {
            record = CKRecord(recordType: RecordType.userProfile.rawValue)
        }
        
        record["username"] = profile.username
        record["displayName"] = profile.displayName
        record["totalScore"] = profile.totalScore
        record["gamesPlayed"] = profile.gamesPlayed
        record["gamesWon"] = profile.gamesWon
        
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
    
    /// Search for users by username
    func searchUsers(username: String) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "username BEGINSWITH %@", username)
        let query = CKQuery(recordType: RecordType.userProfile.rawValue, predicate: predicate)
        
        let (matchResults, _) = try await publicDatabase.records(matching: query)
        
        return matchResults.compactMap { _, result in
            try? result.get()
        }
    }
    
    // MARK: - Game Session Operations
    
    /// Create a new game session
    func createGameSession(_ session: GameSession) async throws {
        let record = CKRecord(recordType: RecordType.gameSession.rawValue)
        
        record["hostRecordName"] = session.hostRecordName
        record["difficulty"] = session.difficulty.rawValue
        record["puzzleData"] = session.puzzleData
        record["solutionData"] = session.solutionData
        record["status"] = session.status.rawValue
        record["createdAt"] = session.createdAt
        
        let savedRecord = try await publicDatabase.save(record)
        session.cloudKitRecordName = savedRecord.recordID.recordName
    }
    
    /// Update game session
    func updateGameSession(_ session: GameSession) async throws {
        guard let recordName = session.cloudKitRecordName else {
            throw CloudKitError.noRecordName
        }
        
        let recordID = CKRecord.ID(recordName: recordName)
        let record = try await publicDatabase.record(for: recordID)
        
        record["status"] = session.status.rawValue
        if let startedAt = session.startedAt {
            record["startedAt"] = startedAt
        }
        if let completedAt = session.completedAt {
            record["completedAt"] = completedAt
        }
        
        _ = try await publicDatabase.save(record)
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
    
    // MARK: - Player State Operations
    
    /// Save player game state
    func savePlayerState(_ state: PlayerGameState, gameRecordName: String) async throws {
        let record = CKRecord(recordType: RecordType.playerGameState.rawValue)
        
        record["playerRecordName"] = state.playerRecordName
        record["playerUsername"] = state.playerUsername
        record["currentBoardData"] = state.currentBoardData
        record["score"] = state.score
        record["correctGuesses"] = state.correctGuesses
        record["incorrectGuesses"] = state.incorrectGuesses
        record["cellsCompleted"] = state.cellsCompleted
        record["joinedAt"] = state.joinedAt
        
        // Create reference to game session
        let gameRecordID = CKRecord.ID(recordName: gameRecordName)
        record["gameSession"] = CKRecord.Reference(recordID: gameRecordID, action: .deleteSelf)
        
        _ = try await publicDatabase.save(record)
    }
    
    /// Subscribe to changes in a game session
    /// Note: This requires the 'gameSession' field to be indexed in CloudKit.
    /// If it fails, the app will fall back to polling for updates.
    func subscribeToGameUpdates(gameRecordName: String) async throws {
        do {
            let gameRecordID = CKRecord.ID(recordName: gameRecordName)
            let predicate = NSPredicate(format: "gameSession == %@", gameRecordID)
            
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
        let predicate = NSPredicate(format: "gameSession == %@", gameRecordID)
        let query = CKQuery(recordType: RecordType.playerGameState.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "score", ascending: false)]
        
        let (matchResults, _) = try await publicDatabase.records(matching: query)
        
        return matchResults.compactMap { _, result in
            try? result.get()
        }
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
            predicate = NSPredicate(format: "gameSession == %@", gameRecordID)
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
    
    /// Send friend request
    func sendFriendRequest(to friendRecordName: String, friendUsername: String, friendDisplayName: String) async throws {
        let record = CKRecord(recordType: RecordType.friendship.rawValue)
        
        guard let currentUser = currentUserRecordName else {
            throw CloudKitError.notAuthenticated
        }
        
        record["userRecordName"] = currentUser
        record["friendRecordName"] = friendRecordName
        record["friendUsername"] = friendUsername
        record["friendDisplayName"] = friendDisplayName
        record["status"] = FriendshipStatus.pending.rawValue
        record["createdAt"] = Date()
        
        _ = try await publicDatabase.save(record)
    }
    
    /// Fetch friendships for current user
    func fetchFriendships() async throws -> [CKRecord] {
        guard let currentUser = currentUserRecordName else {
            throw CloudKitError.notAuthenticated
        }
        
        let predicate = NSPredicate(format: "userRecordName == %@ OR friendRecordName == %@", currentUser, currentUser)
        let query = CKQuery(recordType: RecordType.friendship.rawValue, predicate: predicate)
        
        let (matchResults, _) = try await publicDatabase.records(matching: query)
        
        return matchResults.compactMap { _, result in
            try? result.get()
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
