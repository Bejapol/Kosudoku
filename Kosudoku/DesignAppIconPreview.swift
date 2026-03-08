//
//  AppIconPreview.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/9/26.
//

import SwiftUI

/// Preview different app icon concepts for Kosudoku
/// Screenshot these at 1024x1024 to use as app icons
struct AppIconPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Text("Kosudoku App Icon Concepts")
                    .font(.title)
                    .bold()
                
                // Concept 1: Fast Grid with Collaboration
                AppIconConcept1()
                    .frame(width: 400, height: 400)
                
                Text("Concept 1: Fast Grid")
                    .font(.headline)
                
                // Concept 2: Lightning Sudoku
                AppIconConcept2()
                    .frame(width: 400, height: 400)
                
                Text("Concept 2: Lightning Sudoku")
                    .font(.headline)
                
                // Concept 3: Connected Players
                AppIconConcept3()
                    .frame(width: 400, height: 400)
                
                Text("Concept 3: Connected Players")
                    .font(.headline)
                
                // Concept 4: Speed Numbers
                AppIconConcept4()
                    .frame(width: 400, height: 400)
                
                Text("Concept 4: Speed Numbers")
                    .font(.headline)
            }
            .padding()
        }
    }
}

// MARK: - Concept 1: Fast Grid with Motion Lines
struct AppIconConcept1: View {
    var body: some View {
        ZStack {
            backgroundGradient
            sudokuGrid
            speedLines
            lightningBolt
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.blue, Color.purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: 90, style: .continuous))
    }
    
    private var sudokuGrid: some View {
        VStack(spacing: 4) {
            ForEach(0..<3) { row in
                HStack(spacing: 4) {
                    ForEach(0..<3) { col in
                        gridCell(row: row, col: col)
                    }
                }
            }
        }
        .rotationEffect(.degrees(-5))
    }
    
    private func gridCell(row: Int, col: Int) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.3))
            .frame(width: 80, height: 80)
            .overlay(
                Text("\((row * 3 + col + 1) % 9 + 1)")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private var speedLines: some View {
        ForEach(0..<3) { i in
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.4))
                .frame(width: 120, height: 8)
                .offset(x: 100 + CGFloat(i * 10), y: -120 + CGFloat(i * 40))
                .rotationEffect(.degrees(15))
        }
    }
    
    private var lightningBolt: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 80, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(x: -130, y: -130)
            .shadow(color: .black.opacity(0.3), radius: 10)
    }
}

// MARK: - Concept 2: Lightning Sudoku Grid
struct AppIconConcept2: View {
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.4, blue: 0.9), Color(red: 0.4, green: 0.2, blue: 0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 90, style: .continuous))
            
            // Large sudoku grid outline
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 8)
                .frame(width: 300, height: 300)
            
            // Inner grid divisions
            VStack(spacing: 0) {
                ForEach(0..<2) { _ in
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .frame(height: 4)
                        .frame(width: 300)
                        .padding(.vertical, 96)
                }
            }
            
            HStack(spacing: 0) {
                ForEach(0..<2) { _ in
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .frame(width: 4)
                        .frame(height: 300)
                        .padding(.horizontal, 96)
                }
            }
            
            // Central lightning bolt
            ZStack {
                // Glow effect
                Image(systemName: "bolt.fill")
                    .font(.system(size: 140, weight: .bold))
                    .foregroundColor(.yellow)
                    .blur(radius: 20)
                
                Image(systemName: "bolt.fill")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: .black.opacity(0.4), radius: 15)
            
            // Small collaboration indicators (person icons in corners)
            VStack {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: 340, height: 340)
        }
    }
}

// MARK: - Concept 3: Connected Players on Grid
struct AppIconConcept3: View {
    var body: some View {
        ZStack {
            backgroundLayer
            gridLayer
            connectionLines
            playerAvatars
            centerBolt
        }
    }
    
    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color.cyan, Color.blue, Color.indigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: 90, style: .continuous))
    }
    
    private var gridLayer: some View {
        VStack(spacing: 20) {
            ForEach(0..<3) { _ in
                HStack(spacing: 20) {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 70, height: 70)
                    }
                }
            }
        }
        .opacity(0.6)
    }
    
    private var connectionLines: some View {
        Path { path in
            path.move(to: CGPoint(x: 100, y: 100))
            path.addLine(to: CGPoint(x: 300, y: 100))
            path.addLine(to: CGPoint(x: 300, y: 300))
            path.addLine(to: CGPoint(x: 100, y: 300))
            path.addLine(to: CGPoint(x: 100, y: 100))
            path.addLine(to: CGPoint(x: 300, y: 300))
            path.move(to: CGPoint(x: 300, y: 100))
            path.addLine(to: CGPoint(x: 100, y: 300))
        }
        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
    
    private var playerAvatars: some View {
        VStack {
            HStack {
                PlayerAvatar(number: 1, color: .orange)
                Spacer()
                PlayerAvatar(number: 2, color: .green)
            }
            Spacer()
            HStack {
                PlayerAvatar(number: 3, color: .pink)
                Spacer()
                PlayerAvatar(number: 4, color: .yellow)
            }
        }
        .frame(width: 240, height: 240)
    }
    
    private var centerBolt: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 100, height: 100)
            
            Image(systemName: "bolt.fill")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(color: .black.opacity(0.3), radius: 10)
    }
}

struct PlayerAvatar: View {
    let number: Int
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 60, height: 60)
            
            Text("\(number)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.3), radius: 5)
    }
}

// MARK: - Concept 4: Speed Numbers
struct AppIconConcept4: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.orange, Color.red, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 90, style: .continuous))
            
            // Large sudoku numbers with motion effect
            VStack(spacing: -20) {
                HStack(spacing: -10) {
                    NumberWithMotion(number: "1", offset: 0)
                    NumberWithMotion(number: "2", offset: 20)
                    NumberWithMotion(number: "3", offset: 40)
                }
                HStack(spacing: -10) {
                    NumberWithMotion(number: "4", offset: 10)
                    NumberWithMotion(number: "5", offset: 30)
                    NumberWithMotion(number: "6", offset: 50)
                }
                HStack(spacing: -10) {
                    NumberWithMotion(number: "7", offset: 20)
                    NumberWithMotion(number: "8", offset: 40)
                    NumberWithMotion(number: "9", offset: 60)
                }
            }
            .opacity(0.3)
            
            // Featured center number with speed trail
            ZStack {
                // Speed trail
                ForEach(0..<5) { i in
                    Text("5")
                        .font(.system(size: 180, weight: .black))
                        .foregroundColor(.white.opacity(0.1 - Double(i) * 0.02))
                        .offset(x: CGFloat(i * -15), y: CGFloat(i * -10))
                }
                
                // Main number
                Text("5")
                    .font(.system(size: 180, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20)
            }
            .rotationEffect(.degrees(-10))
            
            // Lightning accent
            Image(systemName: "bolt.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.yellow)
                .offset(x: 140, y: -150)
                .shadow(color: .black.opacity(0.3), radius: 10)
        }
    }
}

struct NumberWithMotion: View {
    let number: String
    let offset: CGFloat
    
    var body: some View {
        Text(number)
            .font(.system(size: 70, weight: .bold))
            .foregroundColor(.white.opacity(0.5))
            .offset(x: offset)
    }
}

// MARK: - Preview
#Preview("App Icon Concepts") {
    AppIconPreview()
}

#Preview("Concept 1") {
    AppIconConcept1()
        .frame(width: 1024, height: 1024)
}

#Preview("Concept 2") {
    AppIconConcept2()
        .frame(width: 1024, height: 1024)
}

#Preview("Concept 3") {
    AppIconConcept3()
        .frame(width: 1024, height: 1024)
}

#Preview("Concept 4") {
    AppIconConcept4()
        .frame(width: 1024, height: 1024)
}
