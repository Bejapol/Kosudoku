//
//  GamePlayerColors.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/22/26.
//

import SwiftUI

/// Predefined palette of player colors - 6 default + 4 premium unlockable
enum PlayerColor: Int, CaseIterable {
    case coral    = 0  // warm red-orange
    case teal     = 1  // cool blue-green
    case amber    = 2  // orange-yellow
    case violet   = 3  // purple
    case lime     = 4  // yellow-green
    case rose     = 5  // hot pink
    // Premium unlockable colors
    case iceBlue        = 6
    case sunsetOrange   = 7
    case forestGreen    = 8
    case midnightPurple = 9

    var color: Color {
        switch self {
        case .coral:          return Color(red: 0.96, green: 0.35, blue: 0.28)
        case .teal:           return Color(red: 0.07, green: 0.69, blue: 0.62)
        case .amber:          return Color(red: 0.96, green: 0.62, blue: 0.11)
        case .violet:         return Color(red: 0.60, green: 0.25, blue: 0.90)
        case .lime:           return Color(red: 0.42, green: 0.78, blue: 0.16)
        case .rose:           return Color(red: 0.93, green: 0.22, blue: 0.58)
        case .iceBlue:        return Color(red: 0.40, green: 0.75, blue: 0.95)
        case .sunsetOrange:   return Color(red: 1.00, green: 0.50, blue: 0.20)
        case .forestGreen:    return Color(red: 0.15, green: 0.55, blue: 0.25)
        case .midnightPurple: return Color(red: 0.35, green: 0.15, blue: 0.60)
        }
    }
    
    /// The 6 original colors available to everyone
    static var defaultColors: [PlayerColor] {
        [.coral, .teal, .amber, .violet, .lime, .rose]
    }
    
    /// The 4 premium colors that must be purchased
    static var premiumColors: [PlayerColor] {
        [.iceBlue, .sunsetOrange, .forestGreen, .midnightPurple]
    }
    
    var displayName: String {
        switch self {
        case .coral: return "Coral"
        case .teal: return "Teal"
        case .amber: return "Amber"
        case .violet: return "Violet"
        case .lime: return "Lime"
        case .rose: return "Rose"
        case .iceBlue: return "Ice Blue"
        case .sunsetOrange: return "Sunset Orange"
        case .forestGreen: return "Forest Green"
        case .midnightPurple: return "Midnight Purple"
        }
    }
}

/// Assigns deterministic colors to players based on join order
struct PlayerColorAssigner {

    /// Given the full list of PlayerGameState objects for a session,
    /// returns a dictionary mapping playerRecordName → PlayerColor.
    /// Players are sorted by joinedAt so all devices produce the same mapping.
    static func assign(players: [PlayerGameState]) -> [String: PlayerColor] {
        let sorted = players.sorted { $0.joinedAt < $1.joinedAt }
        let palette = PlayerColor.allCases
        var result: [String: PlayerColor] = [:]
        for (index, player) in sorted.enumerated() {
            // Use custom color if the player purchased one, otherwise auto-assign
            if let customRaw = player.customColorRawValue,
               let custom = PlayerColor(rawValue: customRaw) {
                result[player.playerRecordName] = custom
            } else {
                result[player.playerRecordName] = palette[index % palette.count]
            }
        }
        return result
    }
}

/// Color blending for overlapping player highlights
extension Color {
    /// Blend an array of Colors by averaging their RGBA components.
    /// Returns Color.clear if the array is empty.
    static func blend(_ colors: [Color]) -> Color {
        guard !colors.isEmpty else { return .clear }

        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        var totalAlpha: CGFloat = 0

        for color in colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            totalRed   += r
            totalGreen += g
            totalBlue  += b
            totalAlpha += a
        }

        let n = CGFloat(colors.count)
        return Color(
            red: Double(totalRed / n),
            green: Double(totalGreen / n),
            blue: Double(totalBlue / n),
            opacity: Double(totalAlpha / n)
        )
    }
}
