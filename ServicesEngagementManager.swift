//
//  ServicesEngagementManager.swift
//  Kosudoku
//
//  Created by Paul Kim on 4/4/26.
//

import Foundation

@Observable
class EngagementManager {
    static let shared = EngagementManager()
    
    // Daily/Weekly challenges loaded from profile
    var dailyChallenges: [DailyChallenge] = []
    var weeklyChallenge: WeeklyChallenge?
    
    // Animated display triggers
    var pendingXPGain: Int = 0
    var pendingRPChange: Int = 0
    var recentLevelUp: Int?
    var recentAchievements: [Achievement] = []
    
    // Tracks state at game start so we can surface level-ups/achievements only at conclusion
    private(set) var levelAtGameStart: Int = 0
    private(set) var achievementsAtGameStart: Set<String> = []
    private(set) var isInGame: Bool = false
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {}
    
    // MARK: - Daily Login
    
    /// Check if today is a new calendar day and update login streak
    func checkDailyLogin(profile: UserProfile) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastLogin = profile.lastLoginDate {
            let lastDay = calendar.startOfDay(for: lastLogin)
            
            if lastDay == today {
                // Already logged in today, no-op
                return
            }
            
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if lastDay == calendar.startOfDay(for: yesterday) {
                // Consecutive day
                profile.loginStreak += 1
            } else if profile.loginStreakSavers > 0 && profile.loginStreak > 0 {
                // Missed day(s) but login streak saver preserves the streak
                profile.loginStreakSavers -= 1
                profile.loginStreak += 1
            } else {
                // Streak broken
                profile.loginStreak = 1
            }
        } else {
            // First login ever
            profile.loginStreak = 1
        }
        
        profile.lastLoginDate = Date()
        
        // Award daily login XP: 10 base + 5 per streak day (cap at 5)
        let streakBonus = min(profile.loginStreak, 5) * 5
        let loginXP = 10 + streakBonus
        awardXP(loginXP, profile: profile, isFirstGameOfDay: false)
    }
    
    /// Claim daily bonus (separate from login check — explicit user action)
    func claimDailyBonus(profile: UserProfile) -> Bool {
        guard !hasDailyBonusBeenClaimed(profile: profile) else { return false }
        profile.lastDailyBonusDate = Date()
        return true
    }
    
    func hasDailyBonusBeenClaimed(profile: UserProfile) -> Bool {
        guard let lastBonus = profile.lastDailyBonusDate else { return false }
        return Calendar.current.isDateInToday(lastBonus)
    }
    
    // MARK: - Challenge Generation
    
    /// Generate daily challenges if needed (3 per day, seeded by date)
    func generateDailyChallenges(profile: UserProfile) {
        let todayString = Self.todayDateString()
        
        if profile.lastChallengeDate == todayString {
            // Already generated today — load from profile
            loadDailyChallenges(from: profile)
            return
        }
        
        // New day — generate fresh challenges
        let seed = Calendar.current.startOfDay(for: Date()).hashValue
        var rng = SeededRandomGenerator(seed: UInt64(bitPattern: Int64(seed)))
        
        let pool: [DailyChallengeType] = [
            .winOnDifficulty(.easy),
            .winOnDifficulty(.medium),
            .winOnDifficulty(.hard),
            .completeCells(30),
            .completeCells(50),
            .scoreAtLeast(200),
            .scoreAtLeast(300),
            .winWithoutHint,
            .winMultiplayer,
            .playGames(3),
            .playGames(5),
        ]
        
        var selected: [DailyChallengeType] = []
        var indices = Array(pool.indices)
        
        for i in 0..<3 {
            let randomIndex = Int(rng.next() % UInt64(indices.count))
            let poolIndex = indices.remove(at: randomIndex)
            selected.append(pool[poolIndex])
            // If we'd exhaust the pool, just use what we have (shouldn't happen with 11 options)
            if indices.isEmpty { break }
            _ = i // suppress unused warning
        }
        
        dailyChallenges = selected.enumerated().map { index, type in
            DailyChallenge(id: index, type: type, currentProgress: 0, isCompleted: false)
        }
        
        profile.lastChallengeDate = todayString
        saveDailyChallenges(to: profile)
    }
    
    /// Generate weekly challenge if needed
    func generateWeeklyChallenge(profile: UserProfile) {
        let weekString = Self.currentWeekString()
        
        if profile.lastChallengeWeek == weekString {
            // Already generated this week — load from profile
            loadWeeklyChallenge(from: profile)
            return
        }
        
        // New week — generate fresh challenge
        let seed = weekString.hashValue
        var rng = SeededRandomGenerator(seed: UInt64(bitPattern: Int64(seed)))
        
        let pool: [WeeklyChallengeType] = [
            .winMultiplayerGames(5),
            .playGames(15),
            .earnTotalScore(2000),
            .completeCells(200),
        ]
        
        let index = Int(rng.next() % UInt64(pool.count))
        
        weeklyChallenge = WeeklyChallenge(
            id: weekString,
            type: pool[index],
            currentProgress: 0,
            isCompleted: false
        )
        
        profile.lastChallengeWeek = weekString
        saveWeeklyChallenge(to: profile)
    }
    
    // MARK: - XP Award
    
    /// Award XP with streak multiplier and first-game-of-day bonus
    func awardXP(_ amount: Int, profile: UserProfile, isFirstGameOfDay: Bool) {
        var finalAmount = Double(amount)
        
        // Apply login streak multiplier
        finalAmount *= profile.loginStreakMultiplier
        
        // Apply 2x if first game of day
        if isFirstGameOfDay {
            finalAmount *= 2.0
        }
        
        // Apply double XP token if active
        if profile.isDoubleXPActive {
            finalAmount *= 2.0
        }
        
        let xpGained = Int(finalAmount)
        let oldLevel = profile.playerLevel
        
        profile.totalXP += xpGained
        profile.playerLevel = levelForXP(profile.totalXP)
        
        pendingXPGain += xpGained
        
        // Auto-unlock level milestone cosmetics (always, regardless of game state)
        if profile.playerLevel > oldLevel {
            for level in (oldLevel + 1)...profile.playerLevel {
                unlockLevelMilestone(level: level, profile: profile)
            }
            
            // Only set the display trigger if NOT in a game — during a game,
            // surfaceGameEndRewards() will handle it at game conclusion.
            if !isInGame {
                recentLevelUp = profile.playerLevel
            }
        }
        
        checkAchievements(profile: profile)
    }
    
    // MARK: - RP Award
    
    /// Award or deduct Rank Points for multiplayer results
    func awardRP(isWin: Bool, opponentAvgRP: Int, profile: UserProfile) {
        let playerTier = RankTier(fromRP: profile.rankPoints)
        let opponentTier = RankTier(fromRP: opponentAvgRP)
        
        var rpChange: Int
        
        if isWin {
            rpChange = 25
            // Bonus if opponent is higher tier
            if opponentTier > playerTier {
                rpChange += 5
            }
            rpChange = max(rpChange, 15) // Minimum gain
        } else {
            rpChange = -15
            // Less penalty if opponent is higher tier
            if opponentTier > playerTier {
                rpChange += 3
            }
            rpChange = max(rpChange, -20) // Maximum loss
        }
        
        let oldTier = profile.rankTier
        profile.rankPoints = max(0, profile.rankPoints + rpChange)
        pendingRPChange += rpChange
        
        // Check for tier change achievement
        let newTier = profile.rankTier
        if newTier > oldTier {
            checkAchievements(profile: profile)
        }
    }
    
    // MARK: - Challenge Progress
    
    /// Update challenge progress based on game events
    func updateChallengeProgress(event: EngagementEvent, profile: UserProfile) {
        var dailyChanged = false
        var weeklyChanged = false
        
        for i in dailyChallenges.indices {
            guard !dailyChallenges[i].isCompleted else { continue }
            
            var progress = 0
            
            switch (dailyChallenges[i].type, event) {
            case (.winOnDifficulty(let required), .gameWon(let actual, _, _)):
                if actual == required { progress = 1 }
                
            case (.completeCells, .cellCompleted):
                progress = 1
                
            case (.scoreAtLeast(let target), .scoreEarned(let score)):
                if score >= target { progress = 1 }
                
            case (.winWithoutHint, .gameWon(_, let usedHint, _)):
                if !usedHint { progress = 1 }
                
            case (.winMultiplayer, .gameWon(_, _, let isMultiplayer)):
                if isMultiplayer { progress = 1 }
                
            case (.playGames, .gamePlayed):
                progress = 1
                
            default:
                break
            }
            
            if progress > 0 {
                dailyChallenges[i].currentProgress += progress
                if dailyChallenges[i].currentProgress >= dailyChallenges[i].type.targetValue {
                    dailyChallenges[i].isCompleted = true
                    // Award challenge XP
                    awardXP(dailyChallenges[i].xpReward, profile: profile, isFirstGameOfDay: false)
                }
                dailyChanged = true
            }
        }
        
        // Weekly challenge
        if var weekly = weeklyChallenge, !weekly.isCompleted {
            var progress = 0
            
            switch (weekly.type, event) {
            case (.winMultiplayerGames, .gameWon(_, _, let isMultiplayer)):
                if isMultiplayer { progress = 1 }
                
            case (.playGames, .gamePlayed):
                progress = 1
                
            case (.earnTotalScore, .scoreEarned(let score)):
                progress = score
                
            case (.completeCells, .cellCompleted):
                progress = 1
                
            default:
                break
            }
            
            if progress > 0 {
                weekly.currentProgress += progress
                if weekly.currentProgress >= weekly.type.targetValue {
                    weekly.isCompleted = true
                    awardXP(weekly.xpReward, profile: profile, isFirstGameOfDay: false)
                }
                weeklyChallenge = weekly
                weeklyChanged = true
            }
        }
        
        // Check completionist achievement
        if dailyChallenges.count == 3 && dailyChallenges.allSatisfy({ $0.isCompleted }) {
            if !profile.hasAchievement(.completionist) {
                profile.unlockAchievement(.completionist)
                if !isInGame {
                    recentAchievements.append(.completionist)
                }
            }
        }
        
        if dailyChanged { saveDailyChallenges(to: profile) }
        if weeklyChanged { saveWeeklyChallenge(to: profile) }
    }
    
    // MARK: - Achievement Checking
    
    func checkAchievements(profile: UserProfile) {
        let checks: [(Achievement, Bool)] = [
            (.firstWin, profile.gamesWon >= 1),
            (.tenWins, profile.gamesWon >= 10),
            (.fiftyWins, profile.gamesWon >= 50),
            (.hundredWins, profile.gamesWon >= 100),
            (.fiveStreak, profile.bestWinStreak >= 5),
            (.tenStreak, profile.bestWinStreak >= 10),
            (.reachSilver, profile.rankTier >= .silver),
            (.reachGold, profile.rankTier >= .gold),
            (.reachPlatinum, profile.rankTier >= .platinum),
            (.reachDiamond, profile.rankTier >= .diamond),
            (.reachMaster, profile.rankTier >= .master),
            (.level10, profile.playerLevel >= 10),
            (.level25, profile.playerLevel >= 25),
            (.level50, profile.playerLevel >= 50),
            (.dailyStreak7, profile.loginStreak >= 7),
            (.dailyStreak30, profile.loginStreak >= 30),
        ]
        
        for (achievement, isMet) in checks {
            if isMet && !profile.hasAchievement(achievement) {
                profile.unlockAchievement(achievement)
                // Only set the display trigger if NOT in a game — during a game,
                // surfaceGameEndRewards() will handle it at game conclusion.
                if !isInGame {
                    recentAchievements.append(achievement)
                }
            }
        }
    }
    
    /// Clear pending display values after UI has shown them
    func clearPendingDisplayValues() {
        pendingXPGain = 0
        pendingRPChange = 0
        recentLevelUp = nil
        recentAchievements = []
    }
    
    // MARK: - Game Lifecycle
    
    /// Snapshot the player's level and achievements before a game begins.
    /// Call this when the game starts so we can detect what changed during the game.
    func snapshotGameStart(profile: UserProfile) {
        levelAtGameStart = profile.playerLevel
        achievementsAtGameStart = Set(profile.unlockedAchievements?.components(separatedBy: ",").filter { !$0.isEmpty } ?? [])
        isInGame = true
        // Clear any stale display values from a previous session
        recentLevelUp = nil
        recentAchievements = []
    }
    
    /// Compare current state against the game-start snapshot and populate
    /// `recentLevelUp` / `recentAchievements` with what the player earned
    /// during this game. Call this at game conclusion before showing overlays.
    func surfaceGameEndRewards(profile: UserProfile) {
        isInGame = false
        
        // Level-up: show the new level if it increased during the game
        if profile.playerLevel > levelAtGameStart {
            recentLevelUp = profile.playerLevel
        }
        
        // Achievements: find any that were unlocked during the game
        let currentAchievements = Set(profile.unlockedAchievements?.components(separatedBy: ",").filter { !$0.isEmpty } ?? [])
        let newAchievements = currentAchievements.subtracting(achievementsAtGameStart)
        recentAchievements = newAchievements.compactMap { Achievement(rawValue: $0) }
    }
    
    // MARK: - Level Milestone Cosmetic Unlocks
    
    private func unlockLevelMilestone(level: Int, profile: UserProfile) {
        guard let milestone = LevelMilestone.milestone(forLevel: level) else { return }
        
        switch milestone.cosmeticType {
        case "profileFrame":
            if !profile.ownsItem(in: profile.ownedProfileFrames, rawValue: milestone.cosmeticRawValue) {
                profile.ownedProfileFrames = UserProfile.addToOwnedSet(profile.ownedProfileFrames, rawValue: milestone.cosmeticRawValue)
            }
        case "titleBadge":
            if !profile.ownsItem(in: profile.ownedTitleBadges, rawValue: milestone.cosmeticRawValue) {
                profile.ownedTitleBadges = UserProfile.addToOwnedSet(profile.ownedTitleBadges, rawValue: milestone.cosmeticRawValue)
            }
        case "victoryAnimation":
            if !profile.ownsItem(in: profile.ownedVictoryAnimations, rawValue: milestone.cosmeticRawValue) {
                profile.ownedVictoryAnimations = UserProfile.addToOwnedSet(profile.ownedVictoryAnimations, rawValue: milestone.cosmeticRawValue)
            }
        case "boardSkin":
            if !profile.ownsItem(in: profile.ownedBoardSkins, rawValue: milestone.cosmeticRawValue) {
                profile.ownedBoardSkins = UserProfile.addToOwnedSet(profile.ownedBoardSkins, rawValue: milestone.cosmeticRawValue)
            }
        case "cellTheme":
            if !profile.ownsItem(in: profile.ownedCellThemes, rawValue: milestone.cosmeticRawValue) {
                profile.ownedCellThemes = UserProfile.addToOwnedSet(profile.ownedCellThemes, rawValue: milestone.cosmeticRawValue)
            }
        default:
            break
        }
    }
    
    // MARK: - Persistence Helpers
    
    private func saveDailyChallenges(to profile: UserProfile) {
        if let data = try? encoder.encode(dailyChallenges),
           let json = String(data: data, encoding: .utf8) {
            profile.dailyChallengeData = json
        }
    }
    
    private func loadDailyChallenges(from profile: UserProfile) {
        guard let json = profile.dailyChallengeData,
              let data = json.data(using: .utf8),
              let challenges = try? decoder.decode([DailyChallenge].self, from: data) else {
            dailyChallenges = []
            return
        }
        dailyChallenges = challenges
    }
    
    private func saveWeeklyChallenge(to profile: UserProfile) {
        if let weekly = weeklyChallenge,
           let data = try? encoder.encode(weekly),
           let json = String(data: data, encoding: .utf8) {
            profile.weeklyChallengeData = json
        }
    }
    
    private func loadWeeklyChallenge(from profile: UserProfile) {
        guard let json = profile.weeklyChallengeData,
              let data = json.data(using: .utf8),
              let weekly = try? decoder.decode(WeeklyChallenge.self, from: data) else {
            weeklyChallenge = nil
            return
        }
        weeklyChallenge = weekly
    }
    
    // MARK: - Date Helpers
    
    private static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private static func currentWeekString() -> String {
        let calendar = Calendar(identifier: .iso8601)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return String(format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
    }
}

// MARK: - Seeded Random Number Generator

/// Simple seeded PRNG for deterministic daily challenge selection
struct SeededRandomGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
