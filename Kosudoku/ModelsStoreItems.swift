//
//  ModelsStoreItems.swift
//  Kosudoku
//
//  Created by Paul Kim on 4/2/26.
//

import Foundation

// MARK: - Cell Themes

enum CellTheme: String, CaseIterable, Codable {
    case classic = "classic"
    case neonGlow = "neonGlow"
    case pastel = "pastel"
    case gradient = "gradient"
    case emerald = "emerald" // Level 25 milestone reward
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .neonGlow: return "Neon Glow"
        case .pastel: return "Pastel"
        case .gradient: return "Gradient"
        case .emerald: return "Emerald"
        }
    }
    
    var price: Int {
        switch self {
        case .classic: return 0
        case .emerald: return 0 // Level reward only
        default: return 8
        }
    }
    
    var isLevelReward: Bool { self == .emerald }
    
    var icon: String {
        switch self {
        case .classic: return "square.grid.3x3"
        case .neonGlow: return "lightbulb.fill"
        case .pastel: return "paintpalette"
        case .gradient: return "circle.lefthalf.filled"
        case .emerald: return "leaf.fill"
        }
    }
}

// MARK: - Board Skins

enum BoardSkin: String, CaseIterable, Codable {
    case classic = "classic"
    case darkMode = "darkMode"
    case woodGrain = "woodGrain"
    case chalkboard = "chalkboard"
    case slate = "slate" // Level 20 milestone reward
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .darkMode: return "Dark Mode"
        case .woodGrain: return "Wood Grain"
        case .chalkboard: return "Chalkboard"
        case .slate: return "Slate"
        }
    }
    
    var price: Int {
        switch self {
        case .classic: return 0
        case .slate: return 0 // Level reward only
        default: return 10
        }
    }
    
    var isLevelReward: Bool { self == .slate }
    
    var icon: String {
        switch self {
        case .classic: return "square.grid.3x3"
        case .darkMode: return "moon.fill"
        case .woodGrain: return "leaf.fill"
        case .chalkboard: return "pencil.and.outline"
        case .slate: return "rectangle.fill"
        }
    }
}

// MARK: - Victory Animations

enum VictoryAnimation: String, CaseIterable, Codable {
    case confetti = "confetti"
    case fireworks = "fireworks"
    case emojiRain = "emojiRain"
    case starBurst = "starBurst" // Level 15 milestone reward
    
    var displayName: String {
        switch self {
        case .confetti: return "Confetti"
        case .fireworks: return "Fireworks"
        case .emojiRain: return "Emoji Rain"
        case .starBurst: return "Star Burst"
        }
    }
    
    var price: Int {
        switch self {
        case .confetti: return 0
        case .starBurst: return 0 // Level reward only
        default: return 6
        }
    }
    
    var isLevelReward: Bool { self == .starBurst }
    
    var icon: String {
        switch self {
        case .confetti: return "party.popper"
        case .fireworks: return "sparkles"
        case .emojiRain: return "face.smiling"
        case .starBurst: return "star.fill"
        }
    }
}

// MARK: - Profile Frames

enum ProfileFrame: String, CaseIterable, Codable {
    case none = "none"
    case gold = "gold"
    case diamond = "diamond"
    case fire = "fire"
    case bronzeGlow = "bronzeGlow"     // Level 5 milestone reward
    case silverShine = "silverShine"   // Level 30 milestone reward
    case goldenAura = "goldenAura"     // Level 50 milestone reward
    case rainbow = "rainbow"           // Level 100 milestone reward
    // Animated frames
    case pulseGold = "pulseGold"
    case shimmerDiamond = "shimmerDiamond"
    case rotatingRainbow = "rotatingRainbow"
    case fireFlicker = "fireFlicker"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .gold: return "Gold"
        case .diamond: return "Diamond"
        case .fire: return "Fire"
        case .bronzeGlow: return "Bronze Glow"
        case .silverShine: return "Silver Shine"
        case .goldenAura: return "Golden Aura"
        case .rainbow: return "Rainbow"
        case .pulseGold: return "Pulse Gold"
        case .shimmerDiamond: return "Shimmer Diamond"
        case .rotatingRainbow: return "Rotating Rainbow"
        case .fireFlicker: return "Fire Flicker"
        }
    }
    
    var price: Int {
        switch self {
        case .none: return 0
        case .bronzeGlow, .silverShine, .goldenAura, .rainbow: return 0 // Level rewards only
        case .pulseGold, .shimmerDiamond: return 12
        case .rotatingRainbow, .fireFlicker: return 15
        default: return 8
        }
    }
    
    var isLevelReward: Bool {
        switch self {
        case .bronzeGlow, .silverShine, .goldenAura, .rainbow: return true
        default: return false
        }
    }
    
    var isAnimated: Bool {
        switch self {
        case .pulseGold, .shimmerDiamond, .rotatingRainbow, .fireFlicker: return true
        default: return false
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "circle"
        case .gold: return "crown.fill"
        case .diamond: return "diamond.fill"
        case .fire: return "flame.fill"
        case .bronzeGlow: return "circle.circle.fill"
        case .silverShine: return "sparkle"
        case .goldenAura: return "sun.max.fill"
        case .rainbow: return "rainbow"
        case .pulseGold: return "waveform.circle.fill"
        case .shimmerDiamond: return "diamond.circle.fill"
        case .rotatingRainbow: return "arrow.trianglehead.2.clockwise.rotate.90.circle.fill"
        case .fireFlicker: return "flame.circle.fill"
        }
    }
}

// MARK: - Title Badges

enum TitleBadge: String, CaseIterable, Codable {
    case none = "none"
    case sudokuMaster = "sudokuMaster"
    case speedDemon = "speedDemon"
    case puzzlePro = "puzzlePro"
    case brainWizard = "brainWizard"
    case dedicated = "dedicated"   // Level 10 milestone reward
    case veteran = "veteran"       // Level 40 milestone reward
    case legend = "legend"         // Level 75 milestone reward
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .sudokuMaster: return "Sudoku Master"
        case .speedDemon: return "Speed Demon"
        case .puzzlePro: return "Puzzle Pro"
        case .brainWizard: return "Brain Wizard"
        case .dedicated: return "Dedicated"
        case .veteran: return "Veteran"
        case .legend: return "Legend"
        }
    }
    
    var price: Int {
        switch self {
        case .none: return 0
        case .dedicated, .veteran, .legend: return 0 // Level rewards only
        default: return 10
        }
    }
    
    var isLevelReward: Bool {
        switch self {
        case .dedicated, .veteran, .legend: return true
        default: return false
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "tag"
        case .sudokuMaster: return "star.fill"
        case .speedDemon: return "bolt.fill"
        case .puzzlePro: return "puzzlepiece.fill"
        case .brainWizard: return "brain.fill"
        case .dedicated: return "heart.fill"
        case .veteran: return "shield.checkered"
        case .legend: return "laurel.leading"
        }
    }
}

// MARK: - Game Invite Themes

enum GameInviteTheme: String, CaseIterable, Codable {
    case classic = "classic"
    case royal = "royal"
    case neon = "neon"
    case tropical = "tropical"
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .royal: return "Royal"
        case .neon: return "Neon"
        case .tropical: return "Tropical"
        }
    }
    
    var price: Int { self == .classic ? 0 : 6 }
    
    var icon: String {
        switch self {
        case .classic: return "envelope.fill"
        case .royal: return "crown.fill"
        case .neon: return "bolt.fill"
        case .tropical: return "sun.max.fill"
        }
    }
}

// MARK: - Game Emotes

enum GameEmote: String, CaseIterable {
    // Classic Pack
    case gg = "gg"
    case sweat = "sweat"
    case fire = "fire"
    case flex = "flex"
    case cool = "cool"
    case mindBlown = "mindBlown"
    // Celebration Pack
    case party = "party"
    case heartEyes = "heartEyes"
    case trophy = "trophy"
    case rocket = "rocket"
    case sparkles = "sparkles"
    case clown = "clown"
    // Animals Pack
    case cat = "cat"
    case dog = "dog"
    case monkey = "monkey"
    case penguin = "penguin"
    case unicorn = "unicorn"
    case dragon = "dragon"
    
    var emoji: String {
        switch self {
        case .gg: return "👏"
        case .sweat: return "😅"
        case .fire: return "🔥"
        case .flex: return "💪"
        case .cool: return "😎"
        case .mindBlown: return "🤯"
        case .party: return "🎉"
        case .heartEyes: return "😍"
        case .trophy: return "🏆"
        case .rocket: return "🚀"
        case .sparkles: return "✨"
        case .clown: return "🤡"
        case .cat: return "🐱"
        case .dog: return "🐶"
        case .monkey: return "🙈"
        case .penguin: return "🐧"
        case .unicorn: return "🦄"
        case .dragon: return "🐉"
        }
    }
    
    var label: String {
        switch self {
        case .gg: return "GG"
        case .sweat: return "Sweat"
        case .fire: return "Fire"
        case .flex: return "Flex"
        case .cool: return "Cool"
        case .mindBlown: return "Mind Blown"
        case .party: return "Party"
        case .heartEyes: return "Love"
        case .trophy: return "Trophy"
        case .rocket: return "Rocket"
        case .sparkles: return "Sparkles"
        case .clown: return "Clown"
        case .cat: return "Cat"
        case .dog: return "Dog"
        case .monkey: return "Monkey"
        case .penguin: return "Penguin"
        case .unicorn: return "Unicorn"
        case .dragon: return "Dragon"
        }
    }
    
    // Pack definitions
    static let classicPack: [GameEmote] = [.gg, .sweat, .fire, .flex, .cool, .mindBlown]
    static let celebrationPack: [GameEmote] = [.party, .heartEyes, .trophy, .rocket, .sparkles, .clown]
    static let animalsPack: [GameEmote] = [.cat, .dog, .monkey, .penguin, .unicorn, .dragon]
}

// MARK: - Number Fonts

import SwiftUI

enum NumberFont: String, CaseIterable, Codable {
    case classic = "classic"
    case handwritten = "handwritten"
    case serif = "serif"
    case bold = "bold"
    case mono = "mono"
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .handwritten: return "Handwritten"
        case .serif: return "Serif"
        case .bold: return "Bold"
        case .mono: return "Monospace"
        }
    }
    
    var price: Int { self == .classic ? 0 : 8 }
    
    var icon: String {
        switch self {
        case .classic: return "textformat"
        case .handwritten: return "pencil.line"
        case .serif: return "textformat.abc"
        case .bold: return "bold"
        case .mono: return "keyboard"
        }
    }
    
    func font(size: CGFloat) -> Font {
        switch self {
        case .classic: return .system(size: size)
        case .handwritten: return .system(size: size, design: .rounded)
        case .serif: return .system(size: size, design: .serif)
        case .bold: return .system(size: size, weight: .black)
        case .mono: return .system(size: size, design: .monospaced)
        }
    }
}

// MARK: - Sound Packs

enum SoundPack: String, CaseIterable, Codable {
    case classic = "classic"
    case retro = "retro"
    case zen = "zen"
    case arcade = "arcade"
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .retro: return "Retro"
        case .zen: return "Zen"
        case .arcade: return "Arcade"
        }
    }
    
    var price: Int { self == .classic ? 0 : 8 }
    
    var icon: String {
        switch self {
        case .classic: return "speaker.wave.2.fill"
        case .retro: return "gamecontroller.fill"
        case .zen: return "leaf.fill"
        case .arcade: return "arcade.stick"
        }
    }
}

// MARK: - Chat Bubble Styles

enum ChatBubbleStyle: String, CaseIterable, Codable {
    case classic = "classic"
    case comic = "comic"
    case minimal = "minimal"
    case neon = "neon"
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .comic: return "Comic"
        case .minimal: return "Minimal"
        case .neon: return "Neon"
        }
    }
    
    var price: Int { self == .classic ? 0 : 6 }
    
    var icon: String {
        switch self {
        case .classic: return "bubble.left.fill"
        case .comic: return "bubble.left.and.exclamationmark.bubble.right.fill"
        case .minimal: return "text.bubble"
        case .neon: return "bubble.left.and.bubble.right.fill"
        }
    }
}

// MARK: - Profile Banners

enum ProfileBanner: String, CaseIterable, Codable {
    case none = "none"
    case sunset = "sunset"
    case ocean = "ocean"
    case forest = "forest"
    case galaxy = "galaxy"
    case fireBanner = "fireBanner"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .sunset: return "Sunset"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .galaxy: return "Galaxy"
        case .fireBanner: return "Fire"
        }
    }
    
    var price: Int { self == .none ? 0 : 10 }
    
    var icon: String {
        switch self {
        case .none: return "rectangle"
        case .sunset: return "sunset.fill"
        case .ocean: return "water.waves"
        case .forest: return "tree.fill"
        case .galaxy: return "sparkles"
        case .fireBanner: return "flame.fill"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .none: return [.clear]
        case .sunset: return [Color.orange, Color.pink, Color.purple]
        case .ocean: return [Color.blue, Color.cyan, Color.teal]
        case .forest: return [Color.green, Color(red: 0.1, green: 0.4, blue: 0.15), Color(red: 0.05, green: 0.2, blue: 0.1)]
        case .galaxy: return [Color.purple, Color.blue, Color(red: 0.1, green: 0.05, blue: 0.2)]
        case .fireBanner: return [Color.red, Color.orange, Color.yellow]
        }
    }
}

// MARK: - Consumable Boost Definitions

enum ConsumableBoost: String, CaseIterable {
    case hintToken = "hintToken"
    case undoShield = "undoShield"
    case streakSaver = "streakSaver"
    case loginStreakSaver = "loginStreakSaver"
    case doubleXPToken = "doubleXPToken"
    
    var displayName: String {
        switch self {
        case .hintToken: return "Hint Token"
        case .undoShield: return "Undo Shield"
        case .streakSaver: return "Streak Saver"
        case .loginStreakSaver: return "Login Streak Saver"
        case .doubleXPToken: return "Double XP (15min)"
        }
    }
    
    var description: String {
        switch self {
        case .hintToken: return "Reveals one correct cell in multiplayer. Limit 1 per game."
        case .undoShield: return "Blocks the penalty from your next wrong move. Limit 1 per game."
        case .streakSaver: return "Preserves your win streak after a loss. Auto-activates."
        case .loginStreakSaver: return "Preserves your login streak if you miss a day. Auto-activates."
        case .doubleXPToken: return "2x XP for 15 minutes. Activate from the store."
        }
    }
    
    var price: Int {
        switch self {
        case .hintToken: return 3
        case .undoShield: return 3
        case .streakSaver: return 5
        case .loginStreakSaver: return 5
        case .doubleXPToken: return 8
        }
    }
    
    var icon: String {
        switch self {
        case .hintToken: return "lightbulb.fill"
        case .undoShield: return "shield.fill"
        case .streakSaver: return "flame.fill"
        case .loginStreakSaver: return "calendar.badge.checkmark"
        case .doubleXPToken: return "arrow.up.forward.circle.fill"
        }
    }
}

// MARK: - StoreDisplayable Conformances

extension NumberFont: StoreDisplayable {
    var storeDisplayName: String { displayName }
    var storePrice: Int { price }
    var storeIcon: String { icon }
}

extension SoundPack: StoreDisplayable {
    var storeDisplayName: String { displayName }
    var storePrice: Int { price }
    var storeIcon: String { icon }
}

extension ChatBubbleStyle: StoreDisplayable {
    var storeDisplayName: String { displayName }
    var storePrice: Int { price }
    var storeIcon: String { icon }
}

extension ProfileBanner: StoreDisplayable {
    var storeDisplayName: String { displayName }
    var storePrice: Int { price }
    var storeIcon: String { icon }
}
