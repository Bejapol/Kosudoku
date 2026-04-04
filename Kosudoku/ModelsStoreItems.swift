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
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .neonGlow: return "Neon Glow"
        case .pastel: return "Pastel"
        case .gradient: return "Gradient"
        }
    }
    
    var price: Int { self == .classic ? 0 : 8 }
    
    var icon: String {
        switch self {
        case .classic: return "square.grid.3x3"
        case .neonGlow: return "lightbulb.fill"
        case .pastel: return "paintpalette"
        case .gradient: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Board Skins

enum BoardSkin: String, CaseIterable, Codable {
    case classic = "classic"
    case darkMode = "darkMode"
    case woodGrain = "woodGrain"
    case chalkboard = "chalkboard"
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .darkMode: return "Dark Mode"
        case .woodGrain: return "Wood Grain"
        case .chalkboard: return "Chalkboard"
        }
    }
    
    var price: Int { self == .classic ? 0 : 10 }
    
    var icon: String {
        switch self {
        case .classic: return "square.grid.3x3"
        case .darkMode: return "moon.fill"
        case .woodGrain: return "leaf.fill"
        case .chalkboard: return "pencil.and.outline"
        }
    }
}

// MARK: - Victory Animations

enum VictoryAnimation: String, CaseIterable, Codable {
    case confetti = "confetti"
    case fireworks = "fireworks"
    case emojiRain = "emojiRain"
    
    var displayName: String {
        switch self {
        case .confetti: return "Confetti"
        case .fireworks: return "Fireworks"
        case .emojiRain: return "Emoji Rain"
        }
    }
    
    var price: Int { self == .confetti ? 0 : 6 }
    
    var icon: String {
        switch self {
        case .confetti: return "party.popper"
        case .fireworks: return "sparkles"
        case .emojiRain: return "face.smiling"
        }
    }
}

// MARK: - Profile Frames

enum ProfileFrame: String, CaseIterable, Codable {
    case none = "none"
    case gold = "gold"
    case diamond = "diamond"
    case fire = "fire"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .gold: return "Gold"
        case .diamond: return "Diamond"
        case .fire: return "Fire"
        }
    }
    
    var price: Int { self == .none ? 0 : 8 }
    
    var icon: String {
        switch self {
        case .none: return "circle"
        case .gold: return "crown.fill"
        case .diamond: return "diamond.fill"
        case .fire: return "flame.fill"
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
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .sudokuMaster: return "Sudoku Master"
        case .speedDemon: return "Speed Demon"
        case .puzzlePro: return "Puzzle Pro"
        case .brainWizard: return "Brain Wizard"
        }
    }
    
    var price: Int { self == .none ? 0 : 10 }
    
    var icon: String {
        switch self {
        case .none: return "tag"
        case .sudokuMaster: return "star.fill"
        case .speedDemon: return "bolt.fill"
        case .puzzlePro: return "puzzlepiece.fill"
        case .brainWizard: return "brain.fill"
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
    case timeFreeze = "timeFreeze"
    case undoShield = "undoShield"
    case streakSaver = "streakSaver"
    
    var displayName: String {
        switch self {
        case .hintToken: return "Hint Token"
        case .timeFreeze: return "Time Freeze"
        case .undoShield: return "Undo Shield"
        case .streakSaver: return "Streak Saver"
        }
    }
    
    var description: String {
        switch self {
        case .hintToken: return "Reveals one correct cell in multiplayer. Limit 1 per game."
        case .timeFreeze: return "Pauses your timer for 30 seconds. Limit 1 per game."
        case .undoShield: return "Blocks the penalty from your next wrong move. Limit 1 per game."
        case .streakSaver: return "Preserves your win streak after a loss. Auto-activates."
        }
    }
    
    var price: Int {
        switch self {
        case .hintToken: return 3
        case .timeFreeze: return 4
        case .undoShield: return 3
        case .streakSaver: return 5
        }
    }
    
    var icon: String {
        switch self {
        case .hintToken: return "lightbulb.fill"
        case .timeFreeze: return "snowflake"
        case .undoShield: return "shield.fill"
        case .streakSaver: return "flame.fill"
        }
    }
}
