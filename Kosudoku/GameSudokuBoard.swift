//
//  SudokuBoard.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation

/// Represents a Sudoku board with 9x9 cells
struct SudokuBoard: Codable, Equatable {
    var cells: [[SudokuCell]]
    
    init() {
        // Initialize empty 9x9 board
        self.cells = Array(repeating: Array(repeating: SudokuCell(), count: 9), count: 9)
    }
    
    init(cells: [[SudokuCell]]) {
        self.cells = cells
    }
    
    subscript(row: Int, col: Int) -> SudokuCell {
        get {
            cells[row][col]
        }
        set {
            cells[row][col] = newValue
        }
    }
    
    /// Convert to JSON string for storage
    func toJSONString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
    
    /// Create from JSON string
    static func fromJSONString(_ string: String) -> SudokuBoard? {
        guard let data = string.data(using: .utf8),
              let board = try? JSONDecoder().decode(SudokuBoard.self, from: data) else {
            return nil
        }
        return board
    }
}

/// Represents a single cell in the Sudoku board
struct SudokuCell: Codable, Equatable {
    var value: Int? // 1-9, or nil if empty
    var isFixed: Bool // true if part of the initial puzzle
    var notes: Set<Int> // Pencil marks (1-9)
    var completedBy: String? // CloudKit record name of player who completed this cell
    
    init(value: Int? = nil, isFixed: Bool = false) {
        self.value = value
        self.isFixed = isFixed
        self.notes = []
        self.completedBy = nil
    }
}
