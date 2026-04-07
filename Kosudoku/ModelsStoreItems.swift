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
        }
    }
    
    var price: Int {
        switch self {
        case .none: return 0
        case .bronzeGlow, .silverShine, .goldenAura, .rainbow: return 0 // Level rewards only
        default: return 8
        }
    }
    
    var isLevelReward: Bool {
        switch self {
        case .bronzeGlow, .silverShine, .goldenAura, .rainbow: return true
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
    case gg = "gg"
    case sweat = "sweat"
    case fire = "fire"
    case flex = "flex"
    case cool = "cool"
    case mindBlown = "mindBlown"
    
    var emoji: String {
        switch self {
        case .gg: return "👏"
        case .sweat: return "😅"
        case .fire: return "🔥"
        case .flex: return "💪"
        case .cool: return "😎"
        case .mindBlown: return "🤯"
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
        }
    }
}

// MARK: - Consumable Boost Definitions

enum ConsumableBoost: String, CaseIterable {
    case hintToken = "hintToken"
    case undoShield = "undoShield"
    case streakSaver = "streakSaver"
    
    var displayName: String {
        switch self {
        case .hintToken: return "Hint Token"
        case .undoShield: return "Undo Shield"
        case .streakSaver: return "Streak Saver"
        }
    }
    
    var description: String {
        switch self {
        case .hintToken: return "Reveals one correct cell in multiplayer. Limit 1 per game."
        case .undoShield: return "Blocks the penalty from your next wrong move. Limit 1 per game."
        case .streakSaver: return "Preserves your win streak after a loss. Auto-activates."
        }
    }
    
    var price: Int {
        switch self {
        case .hintToken: return 3
        case .undoShield: return 3
        case .streakSaver: return 5
        }
    }
    
    var icon: String {
        switch self {
        case .hintToken: return "lightbulb.fill"
        case .undoShield: return "shield.fill"
        case .streakSaver: return "flame.fill"
        }
    }
}
