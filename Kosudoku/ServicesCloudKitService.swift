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
    
    /// Cache for CKRecords to avoid re-fetching on every save.
    /// Keyed by CloudKit record name. Cleared when leaving a game.
    private var playerStateRecordCache: [String: CKRecord] = [:]
    private var gameSessionRecordCache: [String: CKRecord] = [:]
    
    /// Clear cached records (call when leaving a game)
    func clearGameRecordCaches() {
        playerStateRecordCache.removeAll()
        gameSessionRecordCache.removeAll()
    }

    
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
        record["quickets"] = profile.quickets
        record["customColorRawValue"] = profile.customColorRawValue as CKRecordValue?
        // Store the iCloud user record name so other users can identify the owner
        if let userRecordName = currentUserRecordName {
            record["ownerRecordName"] = userRecordName
        }
        
        // Store item fields
        record["equippedCellTheme"] = profile.equippedCellTheme as CKRecordValue?
        record["equippedBoardSkin"] = profile.equippedBoardSkin as CKRecordValue?
        record["equippedVictoryAnimation"] = profile.equippedVictoryAnimation as CKRecordValue?
        record["equippedProfileFrame"] = profile.equippedProfileFrame as CKRecordValue?
        record["equippedTitleBadge"] = profile.equippedTitleBadge as CKRecordValue?
        record["equippedGameInviteTheme"] = profile.equippedGameInviteTheme as CKRecordValue?
        record["ownedCellThemes"] = profile.ownedCellThemes as CKRecordValue?
        record["ownedBoardSkins"] = profile.ownedBoardSkins as CKRecordValue?
        record["ownedVictoryAnimations"] = profile.ownedVictoryAnimations as CKRecordValue?
        record["ownedProfileFrames"] = profile.ownedProfileFrames as CKRecordValue?
        record["ownedTitleBadges"] = profile.ownedTitleBadges as CKRecordValue?
        record["ownedGameInviteThemes"] = profile.ownedGameInviteThemes as CKRecordValue?
        record["ownedPlayerColors"] = profile.ownedPlayerColors as CKRecordValue?
        record["equippedNumberFont"] = profile.equippedNumberFont as CKRecordValue?
        record["equippedSoundPack"] = profile.equippedSoundPack as CKRecordValue?
        record["equippedChatBubbleStyle"] = profile.equippedChatBubbleStyle as CKRecordValue?
        record["equippedProfileBanner"] = profile.equippedProfileBanner as CKRecordValue?
        record["ownedNumberFonts"] = profile.ownedNumberFonts as CKRecordValue?
        record["ownedSoundPacks"] = profile.ownedSoundPacks as CKRecordValue?
        record["ownedChatBubbleStyles"] = profile.ownedChatBubbleStyles as CKRecordValue?
        record["ownedProfileBanners"] = profile.ownedProfileBanners as CKRecordValue?
        record["ownedEmotePacks"] = profile.ownedEmotePacks as CKRecordValue?
        record["profileBio"] = profile.profileBio as CKRecordValue?
        record["hintTokens"] = profile.hintTokens
        
        record["undoShields"] = profile.undoShields
        record["streakSavers"] = profile.streakSavers
        record["loginStreakSavers"] = profile.loginStreakSavers
        record["doubleXPTokens"] = profile.doubleXPTokens
        record["doubleXPActiveUntil"] = profile.doubleXPActiveUntil as CKRecordValue?
        record["hasExtendedStats"] = profile.hasExtendedStats ? 1 : 0
        record["hasEmotePack"] = profile.hasEmotePack ? 1 : 0
        record["currentWinStreak"] = profile.currentWinStreak
        record["bestWinStreak"] = profile.bestWinStreak
        
        // Engagement fields
        record["totalXP"] = profile.totalXP
        record["playerLevel"] = profile.playerLevel
        record["rankPoints"] = profile.rankPoints
        record["loginStreak"] = profile.loginStreak
        record["lastLoginDate"] = profile.lastLoginDate as CKRecordValue?
        record["lastDailyBonusDate"] = profile.lastDailyBonusDate as CKRecordValue?
        record["lastGameCompletedDate"] = profile.lastGameCompletedDate as CKRecordValue?
        record["dailyChallengeData"] = profile.dailyChallengeData as CKRecordValue?
        record["weeklyChallengeData"] = profile.weeklyChallengeData as CKRecordValue?
        record["lastChallengeDate"] = profile.lastChallengeDate as CKRecordValue?
        record["lastChallengeWeek"] = profile.lastChallengeWeek as CKRecordValue?
        record["unlockedAchievements"] = profile.unlockedAchievements as CKRecordValue?
        record["lastActiveDate"] = profile.lastActiveDate as CKRecordValue?
        
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
        profile.quickets = (record["quickets"] as? Int) ?? 5
        profile.customColorRawValue = record["customColorRawValue"] as? Int
        
        // Store item fields
        Self.readStoreFields(from: record, into: profile)
        
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
        profile.quickets = (record["quickets"] as? Int) ?? 5
        profile.customColorRawValue = record["customColorRawValue"] as? Int
        
        // Store item fields
        Self.readStoreFields(from: record, into: profile)
        
        if let avatarAsset = record["avatar"] as? CKAsset,
           let avatarURL = avatarAsset.fileURL,
           let avatarData = try? Data(contentsOf: avatarURL) {
            profile.avatarImageData = avatarData
        }
        
        return profile
    }
    
    /// Read store-related fields from a CloudKit record into a UserProfile
    private static func readStoreFields(from record: CKRecord, into profile: UserProfile) {
        profile.equippedCellTheme = record["equippedCellTheme"] as? String
        profile.equippedBoardSkin = record["equippedBoardSkin"] as? String
        profile.equippedVictoryAnimation = record["equippedVictoryAnimation"] as? String
        profile.equippedProfileFrame = record["equippedProfileFrame"] as? String
        profile.equippedTitleBadge = record["equippedTitleBadge"] as? String
        profile.equippedGameInviteTheme = record["equippedGameInviteTheme"] as? String
        profile.ownedCellThemes = record["ownedCellThemes"] as? String
        profile.ownedBoardSkins = record["ownedBoardSkins"] as? String
        profile.ownedVictoryAnimations = record["ownedVictoryAnimations"] as? String
        profile.ownedProfileFrames = record["ownedProfileFrames"] as? String
        profile.ownedTitleBadges = record["ownedTitleBadges"] as? String
        profile.ownedGameInviteThemes = record["ownedGameInviteThemes"] as? String
        profile.ownedPlayerColors = record["ownedPlayerColors"] as? String
        profile.equippedNumberFont = record["equippedNumberFont"] as? String
        profile.equippedSoundPack = record["equippedSoundPack"] as? String
        profile.equippedChatBubbleStyle = record["equippedChatBubbleStyle"] as? String
        profile.equippedProfileBanner = record["equippedProfileBanner"] as? String
        profile.ownedNumberFonts = record["ownedNumberFonts"] as? String
        profile.ownedSoundPacks = record["ownedSoundPacks"] as? String
        profile.ownedChatBubbleStyles = record["ownedChatBubbleStyles"] as? String
        profile.ownedProfileBanners = record["ownedProfileBanners"] as? String
        profile.ownedEmotePacks = record["ownedEmotePacks"] as? String
        profile.profileBio = record["profileBio"] as? String
        profile.hintTokens = (record["hintTokens"] as? Int) ?? 0
        
        profile.undoShields = (record["undoShields"] as? Int) ?? 0
        profile.streakSavers = (record["streakSavers"] as? Int) ?? 0
        profile.loginStreakSavers = (record["loginStreakSavers"] as? Int) ?? 0
        profile.doubleXPTokens = (record["doubleXPTokens"] as? Int) ?? 0
        profile.doubleXPActiveUntil = record["doubleXPActiveUntil"] as? Date
        profile.hasExtendedStats = ((record["hasExtendedStats"] as? Int) ?? 0) != 0
        profile.hasEmotePack = ((record["hasEmotePack"] as? Int) ?? 0) != 0
        profile.currentWinStreak = (record["currentWinStreak"] as? Int) ?? 0
        profile.bestWinStreak = (record["bestWinStreak"] as? Int) ?? 0
        
        // Engagement fields
        profile.totalXP = (record["totalXP"] as? Int) ?? 0
        profile.playerLevel = (record["playerLevel"] as? Int) ?? 0
        profile.rankPoints = (record["rankPoints"] as? Int) ?? 0
        profile.loginStreak = (record["loginStreak"] as? Int) ?? 0
        profile.lastLoginDate = record["lastLoginDate"] as? Date
        profile.lastDailyBonusDate = record["lastDailyBonusDate"] as? Date
        profile.lastGameCompletedDate = record["lastGameCompletedDate"] as? Date
        profile.dailyChallengeData = record["dailyChallengeData"] as? String
        profile.weeklyChallengeData = record["weeklyChallengeData"] as? String
        profile.lastChallengeDate = record["lastChallengeDate"] as? String
        profile.lastChallengeWeek = record["lastChallengeWeek"] as? String
        profile.unlockedAchievements = record["unlockedAchievements"] as? String
        profile.lastActiveDate = record["lastActiveDate"] as? Date
    }
    
    /// Update only the lastActiveDate field on the current user's profile (lightweight heartbeat)
    func updateLastActiveDate() async {
        guard let profile = currentUserProfile,
              let recordName = profile.cloudKitRecordName else { return }
        do {
            let recordID = CKRecord.ID(recordName: recordName)
            let record = try await publicDatabase.record(for: recordID)
            record["lastActiveDate"] = Date() as CKRecordValue
            _ = try await publicDatabase.save(record)
            profile.lastActiveDate = Date()
        } catch {
            // Non-critical — will retry next heartbeat
        }
    }
    
    /// Fetch the lastActiveDate for multiple users by their owner record names.
    /// Returns a dictionary mapping ownerRecordName → lastActiveDate.
    func fetchOnlineStatus(ownerRecordNames: [String]) async -> [String: Date] {
        guard !ownerRecordNames.isEmpty else { return [:] }
        var result: [String: Date] = [:]
        
        // CloudKit IN queries are limited; batch if needed
        let batches = stride(from: 0, to: ownerRecordNames.count, by: 10).map {
            Array(ownerRecordNames[$0..<min($0 + 10, ownerRecordNames.count)])
        }
        
        for batch in batches {
            let predicate = NSPredicate(format: "ownerRecordName IN %@", batch)
            let query = CKQuery(recordType: RecordType.userProfile.rawValue, predicate: predicate)
            do {
                let (matchResults, _) = try await publicDatabase.records(
                    matching: query,
                    desiredKeys: ["ownerRecordName", "lastActiveDate"],
                    resultsLimit: batch.count
                )
                for (_, recordResult) in matchResults {
                    if let record = try? recordResult.get(),
                       let owner = record["ownerRecordName"] as? String,
                       let lastActive = record["lastActiveDate"] as? Date {
                        result[owner] = lastActive
                    }
                }
            } catch {
                // Non-critical
            }
        }
        return result
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
        record["declinedPlayers"] = session.declinedPlayers as CKRecordValue
        
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
        
        let record: CKRecord
        if let cached = gameSessionRecordCache[recordName] {
            record = cached
        } else {
            let recordID = CKRecord.ID(recordName: recordName)
            record = try await publicDatabase.record(for: recordID)
        }
        
        record["status"] = session.status.rawValue
        record["puzzleData"] = session.puzzleData
        record["declinedPlayers"] = session.declinedPlayers as CKRecordValue
        if let startedAt = session.startedAt {
            record["startedAt"] = startedAt
        }
        if let completedAt = session.completedAt {
            record["completedAt"] = completedAt
        }
        if let countdownStartedAt = session.countdownStartedAt {
            record["countdownStartedAt"] = countdownStartedAt
        }
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            gameSessionRecordCache[recordName] = savedRecord
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Conflict: fetch fresh record and merge puzzleData before retrying.
            // This prevents one player's cell completions from overwriting another's.
            gameSessionRecordCache.removeValue(forKey: recordName)
            let recordID = CKRecord.ID(recordName: recordName)
            let freshRecord = try await publicDatabase.record(for: recordID)
            freshRecord["status"] = session.status.rawValue
            
            // Merge puzzleData: the server may have cells completed by other players
            // that our local board doesn't know about yet. Keep the server's completedBy
            // for any cell it already has, and layer our new completions on top.
            let mergedPuzzleData: String
            if let serverPuzzleData = freshRecord["puzzleData"] as? String,
               let serverBoard = SudokuBoard.fromJSONString(serverPuzzleData),
               let localBoard = SudokuBoard.fromJSONString(session.puzzleData) {
                var merged = serverBoard
                for r in 0..<9 {
                    for c in 0..<9 {
                        let serverCell = serverBoard[r, c]
                        let localCell = localBoard[r, c]
                        // If server already has a completedBy, keep it (first writer wins)
                        if serverCell.completedBy != nil {
                            continue
                        }
                        // If local has a new completion, apply it
                        if localCell.completedBy != nil {
                            merged[r, c] = localCell
                        } else if localCell.value != nil && serverCell.value == nil {
                            merged[r, c] = localCell
                        }
                    }
                }
                mergedPuzzleData = merged.toJSONString()
            } else {
                mergedPuzzleData = session.puzzleData
            }
            freshRecord["puzzleData"] = mergedPuzzleData
            
            freshRecord["declinedPlayers"] = session.declinedPlayers as CKRecordValue
            if let startedAt = session.startedAt { freshRecord["startedAt"] = startedAt }
            if let completedAt = session.completedAt { freshRecord["completedAt"] = completedAt }
            if let countdownStartedAt = session.countdownStartedAt { freshRecord["countdownStartedAt"] = countdownStartedAt }
            let savedRecord = try await publicDatabase.save(freshRecord)
            gameSessionRecordCache[recordName] = savedRecord
        }
    }
    
    /// Update only the status (and completedAt) of a game session in CloudKit,
    /// without touching the local GameSession object.
    func updateGameSessionStatus(recordName: String, status: GameStatus, completedAt: Date?) async throws {
        let recordID = CKRecord.ID(recordName: recordName)
        let record = try await publicDatabase.record(for: recordID)
        record["status"] = status.rawValue
        if let completedAt {
            record["completedAt"] = completedAt
        }
        _ = try await publicDatabase.save(record)
    }
    
    /// Delete completed/abandoned game sessions (and their cascading PlayerGameState records)
    /// that are older than the specified age.
    /// Completed games use `completedAt`; abandoned games fall back to `createdAt`.
    func cleanupOldGameRecords(olderThan maxAge: TimeInterval = 86400) async {
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        // Clean up completed games based on completedAt
        let completedPredicate = NSPredicate(format: "status == %@ AND completedAt < %@",
                                              GameStatus.completed.rawValue, cutoffDate as NSDate)
        await deleteGameRecords(matching: completedPredicate, label: GameStatus.completed.rawValue)
        
        // Clean up abandoned games based on createdAt (they have no completedAt)
        let abandonedPredicate = NSPredicate(format: "status == %@ AND createdAt < %@",
                                              GameStatus.abandoned.rawValue, cutoffDate as NSDate)
        await deleteGameRecords(matching: abandonedPredicate, label: GameStatus.abandoned.rawValue)
    }
    
    private func deleteGameRecords(matching predicate: NSPredicate, label: String) async {
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
                print("🧹 Cleaned up \(recordIDs.count) old \(label) game records from CloudKit")
            }
        } catch {
            print("⚠️ Failed to cleanup old \(label) games: \(error.localizedDescription)")
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
            // Try cached record first to avoid a network round-trip
            if let cached = playerStateRecordCache[existingRecordName] {
                record = cached
            } else {
                let recordID = CKRecord.ID(recordName: existingRecordName)
                record = try await publicDatabase.record(for: recordID)
            }
        } else {
            // Before creating a new record, check if one already exists for this player+game
            // to prevent duplicates from race conditions (e.g. joinGame called twice quickly)
            let gameRecordID = CKRecord.ID(recordName: gameRecordName)
            let reference = CKRecord.Reference(recordID: gameRecordID, action: .none)
            let predicate = NSPredicate(format: "gameSession == %@ AND playerRecordName == %@", reference, state.playerRecordName)
            let query = CKQuery(recordType: RecordType.playerGameState.rawValue, predicate: predicate)
            
            if let (matchResults, _) = try? await publicDatabase.records(matching: query),
               let existingRecord = matchResults.compactMap({ _, result in try? result.get() }).first {
                // Found existing record — reuse it instead of creating a duplicate
                record = existingRecord
                state.cloudKitRecordName = existingRecord.recordID.recordName
                print("🎮 savePlayerState: found existing record, reusing instead of creating duplicate")
            } else {
                // Create new record
                record = CKRecord(recordType: RecordType.playerGameState.rawValue)
                // Set the game session reference only on creation
                record["gameSession"] = CKRecord.Reference(recordID: gameRecordID, action: .deleteSelf)
            }
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
        record["customColorRawValue"] = state.customColorRawValue as CKRecordValue?
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            state.cloudKitRecordName = savedRecord.recordID.recordName
            // Cache the saved record (it has the latest change tag)
            playerStateRecordCache[savedRecord.recordID.recordName] = savedRecord
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Conflict: server has a newer version. Fetch fresh, retry once.
            if let existingRecordName = state.cloudKitRecordName {
                playerStateRecordCache.removeValue(forKey: existingRecordName)
                let recordID = CKRecord.ID(recordName: existingRecordName)
                let freshRecord = try await publicDatabase.record(for: recordID)
                freshRecord["playerRecordName"] = state.playerRecordName
                freshRecord["playerUsername"] = state.playerUsername
                freshRecord["currentBoardData"] = state.currentBoardData
                freshRecord["score"] = state.score
                freshRecord["correctGuesses"] = state.correctGuesses
                freshRecord["incorrectGuesses"] = state.incorrectGuesses
                freshRecord["cellsCompleted"] = state.cellsCompleted
                freshRecord["joinedAt"] = state.joinedAt
                if let lastMoveAt = state.lastMoveAt {
                    freshRecord["lastMoveAt"] = lastMoveAt
                }
                freshRecord["selectedRow"] = state.selectedRow as CKRecordValue?
                freshRecord["selectedCol"] = state.selectedCol as CKRecordValue?
                freshRecord["customColorRawValue"] = state.customColorRawValue as CKRecordValue?
                let savedRecord = try await publicDatabase.save(freshRecord)
                playerStateRecordCache[savedRecord.recordID.recordName] = savedRecord
            } else {
                throw error
            }
        }
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
    
    // MARK: - Group Chat Management
    
    /// Delete all chat messages for a group chat from CloudKit
    func deleteGroupChatMessages(groupChatID: String) async throws {
        let predicate = NSPredicate(format: "groupChatID == %@", groupChatID)
        let query = CKQuery(recordType: RecordType.chatMessage.rawValue, predicate: predicate)
        
        var recordIDsToDelete: [CKRecord.ID] = []
        let (matchResults, _) = try await publicDatabase.records(matching: query)
        for (_, result) in matchResults {
            if let record = try? result.get() {
                recordIDsToDelete.append(record.recordID)
            }
        }
        
        // Batch delete
        if !recordIDsToDelete.isEmpty {
            try await publicDatabase.modifyRecords(saving: [], deleting: recordIDsToDelete)
        }
    }
    
    /// Delete a group chat and all its messages from CloudKit
    func deleteGroupChat(cloudKitRecordName: String, groupChatID: String) async throws {
        // Delete messages first
        try await deleteGroupChatMessages(groupChatID: groupChatID)
        
        // Then delete the chat itself
        let recordID = CKRecord.ID(recordName: cloudKitRecordName)
        try await publicDatabase.deleteRecord(withID: recordID)
    }
    
    /// Remove a member from a group chat in CloudKit
    func leaveGroupChat(cloudKitRecordName: String, memberRecordName: String) async throws {
        let recordID = CKRecord.ID(recordName: cloudKitRecordName)
        let record = try await publicDatabase.record(for: recordID)
        
        var members = (record["memberRecordNames"] as? [String]) ?? []
        members.removeAll { $0 == memberRecordName }
        record["memberRecordNames"] = members as CKRecordValue
        
        _ = try await publicDatabase.save(record)
    }
    
    // MARK: - User Discovery
    
    // Note: CloudKit user discovery APIs (CKDiscoverAllUserIdentitiesOperation,
    // requestApplicationPermission(.userDiscoverability)) were deprecated in iOS 17 with no
    // direct replacement. Apple's recommended alternative (CKShare-based sharing) is a different
    // paradigm that doesn't support automatic contact-based user discovery. These APIs still
    // function and are the only way to discover which contacts use the app. The deprecation
    // warnings are intentional and expected.
    
    /// Request discoverability permission so other users' contacts can find this user
    func requestDiscoverability() async {
        do {
            let status = try await container.requestApplicationPermission(.userDiscoverability)
            print("Discoverability status: \(status.rawValue)")
        } catch {
            print("Failed to request discoverability: \(error.localizedDescription)")
        }
    }
    
    /// Discover contacts who also use the app via CloudKit user discovery
    func discoverContactsUsingApp() async throws -> [CKUserIdentity] {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKDiscoverAllUserIdentitiesOperation()
            var identities: [CKUserIdentity] = []
            
            operation.userIdentityDiscoveredBlock = { identity in
                identities.append(identity)
            }
            
            operation.discoverAllUserIdentitiesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: identities)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            operation.qualityOfService = .userInitiated
            container.add(operation)
        }
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
