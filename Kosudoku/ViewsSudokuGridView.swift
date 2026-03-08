//
//  SudokuGridView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI

struct SudokuGridView: View {
    let board: SudokuBoard
    let selectedCell: (row: Int, col: Int)?
    let onCellTap: (Int, Int) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = geometry.size.width / 9
            
            ZStack {
                // Background
                Color(.systemBackground)
                
                // Grid lines
                GridLines(cellSize: cellSize)
                
                // Cells
                ForEach(0..<9, id: \.self) { row in
                    ForEach(0..<9, id: \.self) { col in
                        SudokuCellView(
                            cell: board[row, col],
                            isSelected: selectedCell?.row == row && selectedCell?.col == col,
                            isInSameRow: selectedCell?.row == row,
                            isInSameCol: selectedCell?.col == col,
                            isInSameBox: isInSameBox(row: row, col: col, selectedRow: selectedCell?.row, selectedCol: selectedCell?.col)
                        )
                        .frame(width: cellSize, height: cellSize)
                        .position(x: CGFloat(col) * cellSize + cellSize / 2,
                                y: CGFloat(row) * cellSize + cellSize / 2)
                        .onTapGesture {
                            onCellTap(row, col)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func isInSameBox(row: Int, col: Int, selectedRow: Int?, selectedCol: Int?) -> Bool {
        guard let selectedRow = selectedRow, let selectedCol = selectedCol else {
            return false
        }
        let boxRow = row / 3
        let boxCol = col / 3
        let selectedBoxRow = selectedRow / 3
        let selectedBoxCol = selectedCol / 3
        return boxRow == selectedBoxRow && boxCol == selectedBoxCol
    }
}

struct GridLines: View {
    let cellSize: CGFloat
    
    var body: some View {
        ZStack {
            // Thin lines
            ForEach(0..<10) { i in
                let offset = CGFloat(i) * cellSize
                
                // Vertical lines
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: i % 3 == 0 ? 2 : 1)
                    .offset(x: offset - cellSize * 4.5)
                
                // Horizontal lines
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: i % 3 == 0 ? 2 : 1)
                    .offset(y: offset - cellSize * 4.5)
            }
        }
    }
}

struct SudokuCellView: View {
    let cell: SudokuCell
    let isSelected: Bool
    let isInSameRow: Bool
    let isInSameCol: Bool
    let isInSameBox: Bool
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor
            
            // Cell content
            if let value = cell.value {
                Text("\(value)")
                    .font(.title)
                    .bold(cell.isFixed)
                    .foregroundColor(cell.isFixed ? .primary : .blue)
            } else if !cell.notes.isEmpty {
                // Show notes
                NotesView(notes: cell.notes)
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.3)
        } else if isInSameRow || isInSameCol || isInSameBox {
            return Color(.systemGray6).opacity(0.5)
        } else {
            return Color.clear
        }
    }
}

struct NotesView: View {
    let notes: Set<Int>
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = geometry.size.width / 3
            
            ForEach(1...9, id: \.self) { number in
                if notes.contains(number) {
                    let row = (number - 1) / 3
                    let col = (number - 1) % 3
                    
                    Text("\(number)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .position(
                            x: CGFloat(col) * cellSize + cellSize / 2,
                            y: CGFloat(row) * cellSize + cellSize / 2
                        )
                }
            }
        }
    }
}

#Preview {
    SudokuGridView(
        board: SudokuBoard(),
        selectedCell: (0, 0),
        onCellTap: { _, _ in }
    )
    .frame(width: 350, height: 350)
    .padding()
}
