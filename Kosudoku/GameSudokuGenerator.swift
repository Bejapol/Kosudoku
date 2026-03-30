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
    
    /// Create a puzzle by removing cells from the solution, ensuring a unique solution.
    ///
    /// For each candidate cell, we tentatively remove it and count solutions.
    /// If the puzzle still has exactly one solution the removal is kept;
    /// otherwise the cell is restored and we move on.
    private static func createPuzzleFromSolution(_ solution: SudokuBoard, difficulty: DifficultyLevel) -> SudokuBoard {
        var puzzle = solution
        
        // Target number of cells to remove
        let cellsToRemove: Int
        switch difficulty {
        case .easy:
            cellsToRemove = 35
        case .medium:
            cellsToRemove = 45
        case .hard:
            cellsToRemove = 50
        case .expert:
            cellsToRemove = 55
        }
        
        // Get all cell positions and shuffle
        var positions = [(Int, Int)]()
        for row in 0..<9 {
            for col in 0..<9 {
                positions.append((row, col))
            }
        }
        positions.shuffle()
        
        // Remove cells one at a time, keeping only removals that preserve uniqueness
        var removed = 0
        for (row, col) in positions {
            if removed >= cellsToRemove {
                break
            }
            
            let savedValue = puzzle[row, col].value
            puzzle[row, col].value = nil
            puzzle[row, col].isFixed = false
            
            if countSolutions(&puzzle, limit: 2) == 1 {
                // Still unique — keep the removal
                removed += 1
            } else {
                // Multiple solutions — put the cell back
                puzzle[row, col].value = savedValue
                puzzle[row, col].isFixed = true
            }
        }
        
        return puzzle
    }
    
    /// Count the number of solutions for the current board state, stopping early at `limit`.
    /// Returns a value between 0 and `limit`.
    private static func countSolutions(_ board: inout SudokuBoard, limit: Int) -> Int {
        // Find the first empty cell
        for row in 0..<9 {
            for col in 0..<9 {
                guard board[row, col].value == nil else { continue }
                
                var count = 0
                for num in 1...9 {
                    if isValid(board, row: row, col: col, num: num) {
                        board[row, col].value = num
                        count += countSolutions(&board, limit: limit - count)
                        board[row, col].value = nil
                        
                        if count >= limit {
                            return count
                        }
                    }
                }
                return count
            }
        }
        // No empty cells — this is a complete valid solution
        return 1
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
