//
//  ScoringSystem.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation

/// Manages the scoring logic for multiplayer Sudoku
struct ScoringSystem {
    
    // Base points for correct guess
    static let correctGuessPoints = 10
    
    // Penalty for incorrect guess
    static let incorrectGuessPenalty = 5
    
    // Bonus points based on difficulty
    static func difficultyMultiplier(for difficulty: DifficultyLevel) -> Double {
        switch difficulty {
        case .easy:
            return 1.0
        case .medium:
            return 1.5
        case .hard:
            return 2.0
        case .expert:
            return 2.5
        }
    }
    
    /// Calculate points for a correct guess
    static func pointsForCorrectGuess(difficulty: DifficultyLevel) -> Int {
        let basePoints = Double(correctGuessPoints)
        let multiplier = difficultyMultiplier(for: difficulty)
        return Int(basePoints * multiplier)
    }
    
    /// Calculate penalty for incorrect guess (scales with difficulty like correct guesses)
    static func pointsForIncorrectGuess(difficulty: DifficultyLevel) -> Int {
        let basePenalty = Double(incorrectGuessPenalty)
        let multiplier = difficultyMultiplier(for: difficulty)
        return Int(basePenalty * multiplier)
    }
    
    /// Calculate final score for a player
    static func calculateFinalScore(
        correctGuesses: Int,
        incorrectGuesses: Int,
        difficulty: DifficultyLevel
    ) -> Int {
        // Base score from correct guesses
        let correctPoints = correctGuesses * pointsForCorrectGuess(difficulty: difficulty)
        
        // Penalty from incorrect guesses (scales with difficulty)
        let incorrectPoints = incorrectGuesses * pointsForIncorrectGuess(difficulty: difficulty)
        
        return max(0, correctPoints - incorrectPoints)
    }
    
    // MARK: - XP Calculations
    
    /// XP earned per correct cell placement
    static func xpForCorrectCell() -> Int {
        return 2
    }
    
    /// XP earned for completing a game
    static func xpForGameCompletion(isWin: Bool, isMultiplayer: Bool) -> Int {
        if isMultiplayer {
            return isWin ? 40 : 10
        }
        return isWin ? 20 : 5
    }
}
