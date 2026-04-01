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
    
    // Speed bonus (points for completing within time thresholds)
    static func speedBonus(cellsCompleted: Int, timeElapsed: TimeInterval) -> Int {
        let avgTimePerCell = timeElapsed / Double(max(cellsCompleted, 1))
        
        // Fast completion (under 10 seconds per cell average)
        if avgTimePerCell < 10 {
            return cellsCompleted * 5
        }
        // Medium speed (10-20 seconds per cell)
        else if avgTimePerCell < 20 {
            return cellsCompleted * 2
        }
        return 0
    }
    
    /// Calculate points for a correct guess
    static func pointsForCorrectGuess(difficulty: DifficultyLevel) -> Int {
        let basePoints = Double(correctGuessPoints)
        let multiplier = difficultyMultiplier(for: difficulty)
        return Int(basePoints * multiplier)
    }
    
    /// Calculate penalty for incorrect guess
    static func pointsForIncorrectGuess() -> Int {
        return -incorrectGuessPenalty
    }
    
    /// Calculate final score for a player
    static func calculateFinalScore(
        correctGuesses: Int,
        incorrectGuesses: Int,
        cellsCompleted: Int,
        difficulty: DifficultyLevel,
        timeElapsed: TimeInterval
    ) -> Int {
        // Base score from correct guesses
        let correctPoints = correctGuesses * pointsForCorrectGuess(difficulty: difficulty)
        
        // Penalty from incorrect guesses
        let incorrectPoints = incorrectGuesses * incorrectGuessPenalty
        
        // Speed bonus
        let speedPoints = speedBonus(cellsCompleted: cellsCompleted, timeElapsed: timeElapsed)
        
        return max(0, correctPoints - incorrectPoints + speedPoints)
    }
}
