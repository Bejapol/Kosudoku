//
//  SudokuGenerator.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation

/// Generates and validates Sudoku puzzles
struct SudokuGenerator {
    
    /// Generate a new Sudoku puzzle with the specified difficulty
    static func generatePuzzle(difficulty: DifficultyLevel) -> (puzzle: SudokuBoard, solution: SudokuBoard) {
        // Generate a complete valid solution
        let solution = generateCompleteSolution()
        
        // Remove cells based on difficulty
        let puzzle = createPuzzleFromSolution(solution, difficulty: difficulty)
        
        return (puzzle, solution)
    }
    
    /// Generate a complete valid Sudoku solution
    private static func generateCompleteSolution() -> SudokuBoard {
        var board = SudokuBoard()
        
        // Fill the board using backtracking
        _ = fillBoard(&board, row: 0, col: 0)
        
        return board
    }
    
    /// Fill the board recursively using backtracking
    private static func fillBoard(_ board: inout SudokuBoard, row: Int, col: Int) -> Bool {
        // Move to next row if we've finished current row
        if col == 9 {
            return fillBoard(&board, row: row + 1, col: 0)
        }
        
        // We've filled all rows successfully
        if row == 9 {
            return true
        }
        
        // Try numbers 1-9 in random order
        let numbers = (1...9).shuffled()
        
        for num in numbers {
            if isValid(board, row: row, col: col, num: num) {
                board[row, col].value = num
                board[row, col].isFixed = true
                
                if fillBoard(&board, row: row, col: col + 1) {
                    return true
                }
                
                // Backtrack
                board[row, col].value = nil
                board[row, col].isFixed = false
            }
        }
        
        return false
    }
    
    /// Create a puzzle by removing cells from the solution
    private static func createPuzzleFromSolution(_ solution: SudokuBoard, difficulty: DifficultyLevel) -> SudokuBoard {
        var puzzle = solution
        
        // Determine how many cells to remove based on difficulty
        let cellsToRemove: Int
        switch difficulty {
        case .easy:
            cellsToRemove = 35 // ~43% filled
        case .medium:
            cellsToRemove = 45 // ~44% filled
        case .hard:
            cellsToRemove = 50 // ~38% filled
        case .expert:
            cellsToRemove = 55 // ~32% filled
        }
        
        // Get all cell positions and shuffle
        var positions = [(Int, Int)]()
        for row in 0..<9 {
            for col in 0..<9 {
                positions.append((row, col))
            }
        }
        positions.shuffle()
        
        // Remove cells
        var removed = 0
        for (row, col) in positions {
            if removed >= cellsToRemove {
                break
            }
            
            puzzle[row, col].value = nil
            puzzle[row, col].isFixed = false
            removed += 1
        }
        
        return puzzle
    }
    
    /// Check if placing a number at a position is valid
    static func isValid(_ board: SudokuBoard, row: Int, col: Int, num: Int) -> Bool {
        // Check row
        for c in 0..<9 {
            if board[row, c].value == num {
                return false
            }
        }
        
        // Check column
        for r in 0..<9 {
            if board[r, col].value == num {
                return false
            }
        }
        
        // Check 3x3 box
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        for r in boxRow..<boxRow + 3 {
            for c in boxCol..<boxCol + 3 {
                if board[r, c].value == num {
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Check if a move is correct against the solution
    static func validateMove(_ board: SudokuBoard, solution: SudokuBoard, row: Int, col: Int, value: Int) -> Bool {
        return solution[row, col].value == value
    }
    
    /// Check if the board is completely filled
    static func isBoardComplete(_ board: SudokuBoard) -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if board[row, col].value == nil {
                    return false
                }
            }
        }
        return true
    }
}
