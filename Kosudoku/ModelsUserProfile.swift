//
//  UserProfile.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var username: String
    var displayName: String
    var avatarImageData: Data?
    var createdAt: Date
    var totalScore: Int
    var gamesPlayed: Int
    var gamesWon: Int
    var quickets: Int = 5
    
    /// Raw value of the purchased custom PlayerColor (nil = not purchased)
    var customColorRawValue: Int?
    
    var hasCustomColor: Bool { customColorRawValue != nil }
    
    // CloudKit user identifier
    var cloudKitRecordName: String?
    
    // MARK: - Equipped Cosmetics (String? raw values, nil = free default)
    
    var equippedCellTheme: String?
    var equippedBoardSkin: String?
    var equippedVictoryAnimation: String?
    var equippedProfileFrame: String?
    var equippedTitleBadge: String?
    var equippedGameInviteTheme: String?
    var equippedNumberFont: String?
    var equippedSoundPack: String?
    var equippedChatBubbleStyle: String?
    var equippedProfileBanner: String?
    
    // MARK: - Owned Sets (comma-separated raw values of purchased items)
    
    var ownedCellThemes: String?
    var ownedBoardSkins: String?
    var ownedVictoryAnimations: String?
    var ownedProfileFrames: String?
    var ownedTitleBadges: String?
    var ownedGameInviteThemes: String?
    var ownedPlayerColors: String?
    var ownedNumberFonts: String?
    var ownedSoundPacks: String?
    var ownedChatBubbleStyles: String?
    var ownedProfileBanners: String?
    var ownedEmotePacks: String?
    
    // MARK: - Consumable Boosts
    
    var hintTokens: Int = 0
    var undoShields: Int = 0
    var streakSavers: Int = 0
    var loginStreakSavers: Int = 0
    var doubleXPTokens: Int = 0
    var doubleXPActiveUntil: Date?
    
    // MARK: - One-Time Unlocks
    
    var hasExtendedStats: Bool = false
    var hasEmotePack: Bool = false
    
    // MARK: - Profile Bio
    
    var profileBio: String?
    
    // MARK: - Win Streak
    
    var currentWinStreak: Int = 0
    var bestWinStreak: Int = 0
    
    // MARK: - XP & Level
    
    var totalXP: Int = 0
    var playerLevel: Int = 0
    
    // MARK: - Rank Points
    
    var rankPoints: Int = 0
    
    // MARK: - Daily Login
    
    var loginStreak: Int = 0
    var lastLoginDate: Date?
    var lastDailyBonusDate: Date?
    
    // MARK: - Challenge Progress (JSON strings, reset daily/weekly by EngagementManager)
    
    var dailyChallengeData: String?
    var weeklyChallengeData: String?
    var lastChallengeDate: String?   // "yyyy-MM-dd"
    var lastChallengeWeek: String?   // "yyyy-Www"
    
    // MARK: - First Game of Day
    
    var lastGameCompletedDate: Date?
    
    // MARK: - Achievements (comma-separated raw values)
    
    var unlockedAchievements: String?
    
    // MARK: - Online Status
    
    var lastActiveDate: Date?
    
    init(username: String, displayName: String, cloudKitRecordName: String? = nil) {
        self.id = UUID()
        self.username = username
        self.displayName = displayName
        self.createdAt = Date()
        self.totalScore = 0
        self.gamesPlayed = 0
        self.gamesWon = 0
        self.quickets = 5
        self.cloudKitRecordName = cloudKitRecordName
    }
    
    // MARK: - Cosmetic Ownership Helpers
    
    /// Check if a cosmetic item is owned (by raw value in the comma-separated set)
    func ownsItem(in ownedSet: String?, rawValue: String) -> Bool {
        guard let owned = ownedSet else { return false }
        return owned.split(separator: ",").contains(Substring(rawValue))
    }
    
    /// Add a raw value to a comma-separated owned set, returns updated string
    static func addToOwnedSet(_ current: String?, rawValue: String) -> String {
        if let current, !current.isEmpty {
            return current + "," + rawValue
        }
        return rawValue
    }
    
    // Typed helpers for each cosmetic category
    
    func ownsCellTheme(_ theme: CellTheme) -> Bool {
        theme == .classic || ownsItem(in: ownedCellThemes, rawValue: theme.rawValue)
    }
    
    func ownsBoardSkin(_ skin: BoardSkin) -> Bool {
        skin == .classic || ownsItem(in: ownedBoardSkins, rawValue: skin.rawValue)
    }
    
    func ownsVictoryAnimation(_ anim: VictoryAnimation) -> Bool {
        anim == .confetti || ownsItem(in: ownedVictoryAnimations, rawValue: anim.rawValue)
    }
    
    func ownsProfileFrame(_ frame: ProfileFrame) -> Bool {
        frame == .none || ownsItem(in: ownedProfileFrames, rawValue: frame.rawValue)
    }
    
    func ownsTitleBadge(_ badge: TitleBadge) -> Bool {
        badge == .none || ownsItem(in: ownedTitleBadges, rawValue: badge.rawValue)
    }
    
    func ownsGameInviteTheme(_ theme: GameInviteTheme) -> Bool {
        theme == .classic || ownsItem(in: ownedGameInviteThemes, rawValue: theme.rawValue)
    }
    
    func ownsPlayerColor(_ color: PlayerColor) -> Bool {
        PlayerColor.defaultColors.contains(color) || ownsItem(in: ownedPlayerColors, rawValue: String(color.rawValue))
    }
    
    func ownsNumberFont(_ font: NumberFont) -> Bool {
        font == .classic || ownsItem(in: ownedNumberFonts, rawValue: font.rawValue)
    }
    
    func ownsSoundPack(_ pack: SoundPack) -> Bool {
        pack == .classic || ownsItem(in: ownedSoundPacks, rawValue: pack.rawValue)
    }
    
    func ownsChatBubbleStyle(_ style: ChatBubbleStyle) -> Bool {
        style == .classic || ownsItem(in: ownedChatBubbleStyles, rawValue: style.rawValue)
    }
    
    func ownsProfileBanner(_ banner: ProfileBanner) -> Bool {
        banner == .none || ownsItem(in: ownedProfileBanners, rawValue: banner.rawValue)
    }
    
    // Computed accessors for equipped items
    
    var activeCellTheme: CellTheme {
        CellTheme(rawValue: equippedCellTheme ?? "") ?? .classic
    }
    
    var activeBoardSkin: BoardSkin {
        BoardSkin(rawValue: equippedBoardSkin ?? "") ?? .classic
    }
    
    var activeVictoryAnimation: VictoryAnimation {
        VictoryAnimation(rawValue: equippedVictoryAnimation ?? "") ?? .confetti
    }
    
    var activeProfileFrame: ProfileFrame {
        ProfileFrame(rawValue: equippedProfileFrame ?? "") ?? .none
    }
    
    var activeTitleBadge: TitleBadge {
        TitleBadge(rawValue: equippedTitleBadge ?? "") ?? .none
    }
    
    var activeGameInviteTheme: GameInviteTheme {
        GameInviteTheme(rawValue: equippedGameInviteTheme ?? "") ?? .classic
    }
    
    var activeNumberFont: NumberFont {
        NumberFont(rawValue: equippedNumberFont ?? "") ?? .classic
    }
    
    var activeSoundPack: SoundPack {
        SoundPack(rawValue: equippedSoundPack ?? "") ?? .classic
    }
    
    var activeChatBubbleStyle: ChatBubbleStyle {
        ChatBubbleStyle(rawValue: equippedChatBubbleStyle ?? "") ?? .classic
    }
    
    var activeProfileBanner: ProfileBanner {
        ProfileBanner(rawValue: equippedProfileBanner ?? "") ?? .none
    }
    
    // MARK: - Double XP
    
    var isDoubleXPActive: Bool {
        guard let until = doubleXPActiveUntil else { return false }
        return Date() < until
    }
    
    // MARK: - Emote Packs
    
    var hasCelebrationPack: Bool {
        ownsItem(in: ownedEmotePacks, rawValue: "celebration")
    }
    
    var hasAnimalsPack: Bool {
        ownsItem(in: ownedEmotePacks, rawValue: "animals")
    }
    
    var availableEmotes: [GameEmote] {
        var emotes: [GameEmote] = []
        if hasEmotePack {
            emotes.append(contentsOf: GameEmote.classicPack)
        }
        if hasCelebrationPack {
            emotes.append(contentsOf: GameEmote.celebrationPack)
        }
        if hasAnimalsPack {
            emotes.append(contentsOf: GameEmote.animalsPack)
        }
        return emotes
    }
    
    // MARK: - Engagement Helpers
    
    var rankTier: RankTier {
        RankTier(fromRP: rankPoints)
    }
    
    /// Login streak XP multiplier: 1.0x to 1.5x (caps at 5-day streak)
    var loginStreakMultiplier: Double {
        1.0 + Double(min(loginStreak, 5)) * 0.1
    }
    
    /// Whether today's first game hasn't been completed yet
    var isFirstGameToday: Bool {
        guard let lastDate = lastGameCompletedDate else { return true }
        return !Calendar.current.isDateInToday(lastDate)
    }
    
    func hasAchievement(_ achievement: Achievement) -> Bool {
        ownsItem(in: unlockedAchievements, rawValue: achievement.rawValue)
    }
    
    func unlockAchievement(_ achievement: Achievement) {
        unlockedAchievements = UserProfile.addToOwnedSet(unlockedAchievements, rawValue: achievement.rawValue)
    }
}
