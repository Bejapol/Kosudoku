//
//  ModelsEngagement.swift
//  Kosudoku
//
//  Created by Paul Kim on 4/4/26.
//

import Foundation
import SwiftUI

// MARK: - Rank Tier

enum RankTier: String, CaseIterable, Codable, Comparable {
    case bronze
    case silver
    case gold
    case platinum
    case diamond
    case master
    
    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        case .master: return "Master"
        }
    }
    
    var icon: String {
        switch self {
        case .bronze: return "shield.fill"
        case .silver: return "shield.lefthalf.filled"
        case .gold: return "medal.fill"
        case .platinum: return "star.circle.fill"
        case .diamond: return "diamond.fill"
        case .master: return "crown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .platinum: return Color(red: 0.4, green: 0.8, blue: 0.85)
        case .diamond: return Color(red: 0.73, green: 0.33, blue: 0.83)
        case .master: return Color(red: 1.0, green: 0.27, blue: 0.27)
        }
    }
    
    var minRP: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 200
        case .gold: return 500
        case .platinum: return 1000
        case .diamond: return 1500
        case .master: return 2000
        }
    }
    
    init(fromRP rp: Int) {
        switch rp {
        case 2000...: self = .master
        case 1500..<2000: self = .diamond
        case 1000..<1500: self = .platinum
        case 500..<1000: self = .gold
        case 200..<500: self = .silver
        default: self = .bronze
        }
    }
    
    // Comparable conformance by tier order
    private var sortOrder: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1
        case .gold: return 2
        case .platinum: return 3
        case .diamond: return 4
        case .master: return 5
        }
    }
    
    static func < (lhs: RankTier, rhs: RankTier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Level System

/// Cumulative XP needed to reach a given level: 50 * level * (level + 1)
func xpForLevel(_ level: Int) -> Int {
    guard level > 0 else { return 0 }
    return 50 * level * (level + 1)
}

/// Calculate level from total XP (inverse of xpForLevel)
func levelForXP(_ xp: Int) -> Int {
    guard xp > 0 else { return 0 }
    // Solve 50 * L * (L+1) <= xp for L
    // L^2 + L - xp/50 <= 0
    // L = (-1 + sqrt(1 + 4*xp/50)) / 2
    let discriminant = 1.0 + 4.0 * Double(xp) / 50.0
    let level = Int((-1.0 + sqrt(discriminant)) / 2.0)
    return max(0, level)
}

/// Progress within the current level for XP bar display
func xpProgressInCurrentLevel(_ xp: Int) -> (current: Int, needed: Int) {
    let level = levelForXP(xp)
    let currentLevelXP = xpForLevel(level)
    let nextLevelXP = xpForLevel(level + 1)
    return (current: xp - currentLevelXP, needed: nextLevelXP - currentLevelXP)
}

// MARK: - Achievement

enum Achievement: String, CaseIterable, Codable, Identifiable {
    // Game Milestones
    case firstWin
    case tenWins
    case fiftyWins
    case hundredWins
    case fiveStreak
    case tenStreak
    
    // Rank Milestones
    case reachSilver
    case reachGold
    case reachPlatinum
    case reachDiamond
    case reachMaster
    
    // Level Milestones
    case level10
    case level25
    case level50
    
    // Streak Milestones
    case dailyStreak7
    case dailyStreak30
    
    // Special
    case completionist
    case expertSolver
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .firstWin: return "First Victory"
        case .tenWins: return "Rising Star"
        case .fiftyWins: return "Seasoned Player"
        case .hundredWins: return "Century Club"
        case .fiveStreak: return "On a Roll"
        case .tenStreak: return "Unstoppable"
        case .reachSilver: return "Silver Shield"
        case .reachGold: return "Gold Standard"
        case .reachPlatinum: return "Platinum Prowess"
        case .reachDiamond: return "Diamond Brilliance"
        case .reachMaster: return "Grand Master"
        case .level10: return "Double Digits"
        case .level25: return "Quarter Century"
        case .level50: return "Half Century"
        case .dailyStreak7: return "Weekly Warrior"
        case .dailyStreak30: return "Monthly Devotion"
        case .completionist: return "Completionist"
        case .expertSolver: return "Expert Solver"
        }
    }
    
    var description: String {
        switch self {
        case .firstWin: return "Win your first game"
        case .tenWins: return "Win 10 games"
        case .fiftyWins: return "Win 50 games"
        case .hundredWins: return "Win 100 games"
        case .fiveStreak: return "Win 5 games in a row"
        case .tenStreak: return "Win 10 games in a row"
        case .reachSilver: return "Reach Silver rank"
        case .reachGold: return "Reach Gold rank"
        case .reachPlatinum: return "Reach Platinum rank"
        case .reachDiamond: return "Reach Diamond rank"
        case .reachMaster: return "Reach Master rank"
        case .level10: return "Reach Level 10"
        case .level25: return "Reach Level 25"
        case .level50: return "Reach Level 50"
        case .dailyStreak7: return "Log in 7 days in a row"
        case .dailyStreak30: return "Log in 30 days in a row"
        case .completionist: return "Complete all daily challenges in one day"
        case .expertSolver: return "Win a game on Expert difficulty"
        }
    }
    
    var icon: String {
        switch self {
        case .firstWin: return "trophy"
        case .tenWins: return "star.fill"
        case .fiftyWins: return "star.circle.fill"
        case .hundredWins: return "medal.fill"
        case .fiveStreak: return "flame"
        case .tenStreak: return "flame.fill"
        case .reachSilver: return "shield.lefthalf.filled"
        case .reachGold: return "medal.fill"
        case .reachPlatinum: return "star.circle.fill"
        case .reachDiamond: return "diamond.fill"
        case .reachMaster: return "crown.fill"
        case .level10: return "10.circle.fill"
        case .level25: return "25.circle.fill"
        case .level50: return "50.circle.fill"
        case .dailyStreak7: return "calendar.badge.checkmark"
        case .dailyStreak30: return "calendar.badge.clock"
        case .completionist: return "checkmark.seal.fill"
        case .expertSolver: return "brain.fill"
        }
    }
    
    var category: AchievementCategory {
        switch self {
        case .firstWin, .tenWins, .fiftyWins, .hundredWins, .fiveStreak, .tenStreak:
            return .gameMilestones
        case .reachSilver, .reachGold, .reachPlatinum, .reachDiamond, .reachMaster:
            return .rankMilestones
        case .level10, .level25, .level50:
            return .levelMilestones
        case .dailyStreak7, .dailyStreak30, .completionist, .expertSolver:
            return .special
        }
    }
}

enum AchievementCategory: String, CaseIterable {
    case gameMilestones
    case rankMilestones
    case levelMilestones
    case special
    
    var displayName: String {
        switch self {
        case .gameMilestones: return "Game Milestones"
        case .rankMilestones: return "Rank Milestones"
        case .levelMilestones: return "Level Milestones"
        case .special: return "Special"
        }
    }
}

// MARK: - Daily Challenge

enum DailyChallengeType: Codable, Equatable {
    case winOnDifficulty(DifficultyLevel)
    case completeCells(Int)
    case scoreAtLeast(Int)
    case winWithoutHint
    case winMultiplayer
    case playGames(Int)
    
    var displayName: String {
        switch self {
        case .winOnDifficulty(let difficulty):
            return "Win on \(difficulty.rawValue.capitalized)"
        case .completeCells(let count):
            return "Complete \(count) cells"
        case .scoreAtLeast(let score):
            return "Score \(score)+ in a game"
        case .winWithoutHint:
            return "Win without a hint"
        case .winMultiplayer:
            return "Win a multiplayer game"
        case .playGames(let count):
            return "Play \(count) games"
        }
    }
    
    var icon: String {
        switch self {
        case .winOnDifficulty: return "trophy"
        case .completeCells: return "square.grid.3x3"
        case .scoreAtLeast: return "chart.bar.fill"
        case .winWithoutHint: return "lightbulb.slash"
        case .winMultiplayer: return "person.2.fill"
        case .playGames: return "gamecontroller.fill"
        }
    }
    
    var targetValue: Int {
        switch self {
        case .winOnDifficulty: return 1
        case .completeCells(let count): return count
        case .scoreAtLeast: return 1
        case .winWithoutHint: return 1
        case .winMultiplayer: return 1
        case .playGames(let count): return count
        }
    }
}

struct DailyChallenge: Identifiable, Codable, Equatable {
    let id: Int // 0, 1, or 2
    let type: DailyChallengeType
    var currentProgress: Int
    var isCompleted: Bool
    
    var xpReward: Int { 25 }
}

// MARK: - Weekly Challenge

enum WeeklyChallengeType: Codable, Equatable {
    case winMultiplayerGames(Int)
    case playGames(Int)
    case earnTotalScore(Int)
    case completeCells(Int)
    
    var displayName: String {
        switch self {
        case .winMultiplayerGames(let count):
            return "Win \(count) multiplayer games"
        case .playGames(let count):
            return "Play \(count) games"
        case .earnTotalScore(let score):
            return "Earn \(score) total score"
        case .completeCells(let count):
            return "Complete \(count) cells"
        }
    }
    
    var icon: String {
        switch self {
        case .winMultiplayerGames: return "person.2.fill"
        case .playGames: return "gamecontroller.fill"
        case .earnTotalScore: return "chart.bar.fill"
        case .completeCells: return "square.grid.3x3"
        }
    }
    
    var targetValue: Int {
        switch self {
        case .winMultiplayerGames(let count): return count
        case .playGames(let count): return count
        case .earnTotalScore(let score): return score
        case .completeCells(let count): return count
        }
    }
}

struct WeeklyChallenge: Identifiable, Codable, Equatable {
    let id: String // ISO week identifier e.g. "2026-W14"
    let type: WeeklyChallengeType
    var currentProgress: Int
    var isCompleted: Bool
    
    var xpReward: Int { 75 }
}

// MARK: - Engagement Event (for challenge progress tracking)

enum EngagementEvent {
    case cellCompleted
    case gameWon(difficulty: DifficultyLevel, usedHint: Bool, isMultiplayer: Bool)
    case gamePlayed
    case scoreEarned(Int)
    case multiplayerWon
}

// MARK: - Level Milestone Rewards

struct LevelMilestone {
    let level: Int
    let rewardDescription: String
    let cosmeticType: String // e.g. "profileFrame", "titleBadge", "victoryAnimation", "boardSkin", "cellTheme"
    let cosmeticRawValue: String
    
    static let milestones: [LevelMilestone] = [
        LevelMilestone(level: 5, rewardDescription: "Profile Frame: Bronze Glow", cosmeticType: "profileFrame", cosmeticRawValue: "bronzeGlow"),
        LevelMilestone(level: 10, rewardDescription: "Title Badge: Dedicated", cosmeticType: "titleBadge", cosmeticRawValue: "dedicated"),
        LevelMilestone(level: 15, rewardDescription: "Victory Animation: Star Burst", cosmeticType: "victoryAnimation", cosmeticRawValue: "starBurst"),
        LevelMilestone(level: 20, rewardDescription: "Board Skin: Slate", cosmeticType: "boardSkin", cosmeticRawValue: "slate"),
        LevelMilestone(level: 25, rewardDescription: "Cell Theme: Emerald", cosmeticType: "cellTheme", cosmeticRawValue: "emerald"),
        LevelMilestone(level: 30, rewardDescription: "Profile Frame: Silver Shine", cosmeticType: "profileFrame", cosmeticRawValue: "silverShine"),
        LevelMilestone(level: 40, rewardDescription: "Title Badge: Veteran", cosmeticType: "titleBadge", cosmeticRawValue: "veteran"),
        LevelMilestone(level: 50, rewardDescription: "Profile Frame: Golden Aura", cosmeticType: "profileFrame", cosmeticRawValue: "goldenAura"),
        LevelMilestone(level: 75, rewardDescription: "Title Badge: Legend", cosmeticType: "titleBadge", cosmeticRawValue: "legend"),
        LevelMilestone(level: 100, rewardDescription: "Profile Frame: Rainbow", cosmeticType: "profileFrame", cosmeticRawValue: "rainbow"),
    ]
    
    static func milestone(forLevel level: Int) -> LevelMilestone? {
        milestones.first { $0.level == level }
    }
    
    static func milestonesUpTo(level: Int) -> [LevelMilestone] {
        milestones.filter { $0.level <= level }
    }
}
