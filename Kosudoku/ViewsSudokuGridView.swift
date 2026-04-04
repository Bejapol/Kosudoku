//
//  SudokuGridView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI

// MARK: - Board Skin Colors

extension BoardSkin {
    var backgroundColor: Color {
        switch self {
        case .classic: return Color(.systemBackground)
        case .darkMode: return Color(red: 0.12, green: 0.12, blue: 0.14)
        case .woodGrain: return Color(red: 0.82, green: 0.71, blue: 0.55)
        case .chalkboard: return Color(red: 0.18, green: 0.32, blue: 0.22)
        }
    }
}

struct SudokuGridView: View {
    let board: SudokuBoard
    let selectedCell: (row: Int, col: Int)?
    let onCellTap: (Int, Int) -> Void
    let currentPlayerColor: Color
    let cellSelections: [String: [PlayerColor]]  // "row-col" → colors of other players selecting that cell
    let colorMap: [String: PlayerColor]           // playerRecordName → assigned color
    @Binding var cellEffect: CellEffect?
    var cellTheme: CellTheme = .classic
    var boardSkin: BoardSkin = .classic
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = geometry.size.width / 9
            
            ZStack {
                // Background
                boardSkin.backgroundColor
                
                // Grid lines
                GridLines(cellSize: cellSize, boardSkin: boardSkin)
                
                // Cells
                ForEach(0..<9, id: \.self) { row in
                    ForEach(0..<9, id: \.self) { col in
                        let key = "\(row)-\(col)"
                        let otherSelectingColors = cellSelections[key] ?? []
                        let completedByColor: Color? = {
                            guard let completedBy = board[row, col].completedBy,
                                  let playerColor = colorMap[completedBy] else { return nil }
                            return playerColor.color
                        }()
                        
                        SudokuCellView(
                            cell: board[row, col],
                            isSelected: selectedCell?.row == row && selectedCell?.col == col,
                            isInSameRow: selectedCell?.row == row,
                            isInSameCol: selectedCell?.col == col,
                            isInSameBox: isInSameBox(row: row, col: col, selectedRow: selectedCell?.row, selectedCol: selectedCell?.col),
                            currentPlayerColor: currentPlayerColor,
                            otherSelectingColors: otherSelectingColors,
                            completedByColor: completedByColor,
                            cellTheme: cellTheme
                        )
                        .frame(width: cellSize, height: cellSize)
                        .contentShape(Rectangle())  // Makes entire cell area tappable
                        .position(
                            x: CGFloat(col) * cellSize + cellSize / 2,
                            y: CGFloat(row) * cellSize + cellSize / 2
                        )
                        .onTapGesture {
                            onCellTap(row, col)
                        }
                    }
                }
                
                // Cell effect overlay
                if let effect = cellEffect {
                    let x = CGFloat(effect.col) * cellSize + cellSize / 2
                    let y = CGFloat(effect.row) * cellSize + cellSize / 2
                    
                    Group {
                        switch effect.kind {
                        case .correct:
                            CorrectCellEffect(color: effect.color, cellSize: cellSize) {
                                cellEffect = nil
                            }
                        case .incorrect:
                            IncorrectCellEffect(value: effect.value, color: effect.color, cellSize: cellSize) {
                                cellEffect = nil
                            }
                        }
                    }
                    .id(effect.id)
                    .position(x: x, y: y)
                    
                    // Floating points label
                    PointsFloatEffect(points: effect.points, isCorrect: effect.kind == .correct)
                        .id("pts-\(effect.id)")
                        .position(x: x, y: y)
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
    var boardSkin: BoardSkin = .classic
    
    private var thinLineColor: Color {
        switch boardSkin {
        case .classic: return Color(.systemGray4)
        case .darkMode: return Color.white.opacity(0.2)
        case .woodGrain: return Color.brown.opacity(0.4)
        case .chalkboard: return Color.white.opacity(0.25)
        }
    }
    
    private var thickLineColor: Color {
        switch boardSkin {
        case .classic: return Color(.label)
        case .darkMode: return Color.white.opacity(0.8)
        case .woodGrain: return Color.brown.opacity(0.8)
        case .chalkboard: return Color.white.opacity(0.7)
        }
    }
    
    var body: some View {
        ZStack {
            // Thin cell lines
            ForEach(0..<10) { i in
                if i % 3 != 0 {
                    let offset = CGFloat(i) * cellSize
                    
                    // Vertical lines
                    Rectangle()
                        .fill(thinLineColor)
                        .frame(width: 1)
                        .offset(x: offset - cellSize * 4.5)
                    
                    // Horizontal lines
                    Rectangle()
                        .fill(thinLineColor)
                        .frame(height: 1)
                        .offset(y: offset - cellSize * 4.5)
                }
            }
            
            // Thick 3x3 box borders
            ForEach(0..<4) { i in
                let offset = CGFloat(i * 3) * cellSize
                
                // Vertical lines
                Rectangle()
                    .fill(thickLineColor)
                    .frame(width: 3)
                    .offset(x: offset - cellSize * 4.5)
                
                // Horizontal lines
                Rectangle()
                    .fill(thickLineColor)
                    .frame(height: 3)
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
    let currentPlayerColor: Color
    let otherSelectingColors: [PlayerColor]
    let completedByColor: Color?
    var cellTheme: CellTheme = .classic
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor
            
            // Theme-specific cell fill overlay
            cellThemeOverlay
            
            // Cell content
            if let value = cell.value {
                Text("\(value)")
                    .font(.title)
                    .bold(cell.isFixed)
                    .foregroundColor(cell.isFixed ? .primary : (completedByColor ?? currentPlayerColor))
                    .shadow(color: cellTheme == .neonGlow ? (completedByColor ?? currentPlayerColor).opacity(0.6) : .clear, radius: 4)
            } else if !cell.notes.isEmpty {
                // Show notes
                NotesView(notes: cell.notes)
            }
        }
    }
    
    @ViewBuilder
    private var cellThemeOverlay: some View {
        switch cellTheme {
        case .classic:
            EmptyView()
        case .neonGlow:
            if cell.value != nil && !cell.isFixed {
                RoundedRectangle(cornerRadius: 2)
                    .fill((completedByColor ?? currentPlayerColor).opacity(0.1))
            }
        case .pastel:
            if cell.value != nil && !cell.isFixed {
                RoundedRectangle(cornerRadius: 2)
                    .fill((completedByColor ?? currentPlayerColor).opacity(0.08))
            }
        case .gradient:
            if cell.value != nil && !cell.isFixed {
                LinearGradient(
                    colors: [(completedByColor ?? currentPlayerColor).opacity(0.15), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    private var backgroundColor: Color {
        var highlights: [Color] = []
        
        // Current player's own selection
        if isSelected {
            highlights.append(currentPlayerColor.opacity(0.3))
        }
        
        // Other players' selections (semi-transparent)
        for playerColor in otherSelectingColors {
            highlights.append(playerColor.color.opacity(0.3))
        }
        
        // If any highlights exist, blend them
        if !highlights.isEmpty {
            return Color.blend(highlights)
        }
        
        // Same row/col/box as selected cell
        if isInSameRow || isInSameCol || isInSameBox {
            return Color(.systemGray6).opacity(0.5)
        }
        
        return Color.clear
    }
}

// MARK: - Cell Effects

/// Overlay that plays a bright flash and sparkle particles for a correct guess
struct CorrectCellEffect: View {
    let color: Color
    let cellSize: CGFloat
    var onComplete: () -> Void = {}
    
    @State private var flash = false
    @State private var sparkles: [Sparkle] = []
    @State private var sparksVisible = true
    
    struct Sparkle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var angle: Double  // direction of travel in radians
        var speed: CGFloat
        var size: CGFloat
    }
    
    var body: some View {
        ZStack {
            // Bright flash fill
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(flash ? 0.0 : 0.6))
                .frame(width: cellSize, height: cellSize)
            
            // Sparkle particles
            if sparksVisible {
                ForEach(sparkles) { spark in
                    Circle()
                        .fill(color)
                        .frame(width: spark.size, height: spark.size)
                        .offset(x: spark.x, y: spark.y)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            // Generate random sparkle particles
            sparkles = (0..<8).map { _ in
                let angle = Double.random(in: 0...(2 * .pi))
                return Sparkle(
                    x: 0, y: 0,
                    angle: angle,
                    speed: CGFloat.random(in: 20...45),
                    size: CGFloat.random(in: 3...6)
                )
            }
            
            // Animate flash out
            withAnimation(.easeOut(duration: 0.4)) {
                flash = true
            }
            
            // Animate sparkles outward
            withAnimation(.easeOut(duration: 0.5)) {
                sparkles = sparkles.map { spark in
                    var s = spark
                    s.x = cos(spark.angle) * spark.speed
                    s.y = sin(spark.angle) * spark.speed
                    s.size = 1
                    return s
                }
            }
            
            // Remove after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                sparksVisible = false
                onComplete()
            }
        }
    }
}

/// Overlay that briefly shows the wrong digit then blinks and fades it away
struct IncorrectCellEffect: View {
    let value: Int
    let color: Color
    let cellSize: CGFloat
    var onComplete: () -> Void = {}
    
    @State private var opacity: Double = 1.0
    @State private var shakeOffset: CGFloat = 0
    @State private var bgOpacity: Double = 0.4
    
    var body: some View {
        ZStack {
            // Red tinted background
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.red.opacity(bgOpacity))
                .frame(width: cellSize, height: cellSize)
            
            // The wrong digit
            Text("\(value)")
                .font(.title)
                .foregroundColor(.red)
                .opacity(opacity)
                .offset(x: shakeOffset)
        }
        .allowsHitTesting(false)
        .onAppear {
            // Quick shake
            withAnimation(.linear(duration: 0.06).repeatCount(5, autoreverses: true)) {
                shakeOffset = 4
            }
            
            // Fade out the digit and background
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                opacity = 0
                bgOpacity = 0
            }
            
            // Clean up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                onComplete()
            }
        }
    }
}

/// Floating "+N" or "-N" label that drifts up (correct) or down (incorrect) and fades out
struct PointsFloatEffect: View {
    let points: Int
    let isCorrect: Bool
    
    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 1.0
    
    private var label: String {
        if points >= 0 {
            return "+\(points)"
        } else {
            return "\(points)"
        }
    }
    
    var body: some View {
        Text(label)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(isCorrect ? .green : .red)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            .offset(y: offsetY)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    offsetY = isCorrect ? -40 : 40
                    opacity = 0
                }
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
        onCellTap: { _, _ in },
        currentPlayerColor: PlayerColor.coral.color,
        cellSelections: [:],
        colorMap: [:],
        cellEffect: .constant(nil),
        cellTheme: .classic,
        boardSkin: .classic
    )
    .frame(width: 350, height: 350)
    .padding()
}
