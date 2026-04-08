//
//  ViewsExtendedStatsView.swift
//  Kosudoku
//
//  Created by Paul Kim on 4/3/26.
//

import SwiftUI
import SwiftData

struct ExtendedStatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<GameSession> { $0.completedAt != nil })
    private var completedGames: [GameSession]
    @Query private var allPlayerStates: [PlayerGameState]
    
    private var cloudKitService: CloudKitService { CloudKitService.shared }
    
    private var currentRecordName: String? {
        cloudKitService.currentUserRecordName
    }
    
    /// All PlayerGameState records belonging to the current user in completed games
    private var myStates: [PlayerGameState] {
        guard let recordName = currentRecordName else { return [] }
        let completedGameIDs = Set(completedGames.map(\.id))
        return allPlayerStates.filter {
            $0.playerRecordName == recordName && completedGameIDs.contains($0.gameSessionID ?? UUID())
        }
    }
    
    /// Map gameSessionID → GameSession for easy lookup
    private var gameMap: [UUID: GameSession] {
        Dictionary(uniqueKeysWithValues: completedGames.map { ($0.id, $0) })
    }
    
    var body: some View {
        List {
            if myStates.isEmpty {
                ContentUnavailableView(
                    "No Data Yet",
                    systemImage: "chart.bar",
                    description: Text("Complete some games to see your detailed stats")
                )
            } else {
                overviewSection
                accuracySection
                difficultyBreakdownSection
                recentGamesSection
            }
        }
        .navigationTitle("Extended Stats")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Overview
    
    private var overviewSection: some View {
        Section("Overview") {
            HStack {
                Text("Games Completed")
                Spacer()
                Text("\(myStates.count)")
                    .bold()
            }
            
            HStack {
                Text("Total Cells Solved")
                Spacer()
                Text("\(myStates.reduce(0) { $0 + $1.cellsCompleted.count })")
                    .bold()
            }
            
            HStack {
                Text("Total Score")
                Spacer()
                Text("\(myStates.reduce(0) { $0 + $1.score })")
                    .bold()
            }
            
            HStack {
                Text("Best Single-Game Score")
                Spacer()
                Text("\(myStates.map(\.score).max() ?? 0)")
                    .bold()
                    .foregroundColor(.green)
            }
            
            if let fastest = fastestSolveTime {
                HStack {
                    Text("Fastest Game")
                    Spacer()
                    Text(formatTime(fastest))
                        .bold()
                        .foregroundColor(.blue)
                }
            }
            
            if !averageSolveTimesByDifficulty.isEmpty {
                HStack {
                    Text("Avg Solve Time")
                    Spacer()
                    let overall = myGameTimes.isEmpty ? 0 : myGameTimes.reduce(0, +) / Double(myGameTimes.count)
                    Text(formatTime(overall))
                        .bold()
                }
            }
        }
    }
    
    // MARK: - Accuracy
    
    private var accuracySection: some View {
        let totalCorrect = myStates.reduce(0) { $0 + $1.correctGuesses }
        let totalIncorrect = myStates.reduce(0) { $0 + $1.incorrectGuesses }
        let totalGuesses = totalCorrect + totalIncorrect
        let accuracy = totalGuesses > 0 ? Double(totalCorrect) / Double(totalGuesses) * 100 : 0
        
        return Section("Accuracy") {
            HStack {
                Label("Correct Guesses", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Spacer()
                Text("\(totalCorrect)")
                    .bold()
            }
            
            HStack {
                Label("Incorrect Guesses", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
                Spacer()
                Text("\(totalIncorrect)")
                    .bold()
            }
            
            HStack {
                Text("Accuracy Rate")
                Spacer()
                Text(String(format: "%.1f%%", accuracy))
                    .bold()
                    .foregroundColor(accuracy > 90 ? .green : accuracy > 70 ? .orange : .red)
            }
        }
    }
    
    // MARK: - Difficulty Breakdown
    
    private var difficultyBreakdownSection: some View {
        Section("By Difficulty") {
            ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                let states = statesForDifficulty(difficulty)
                if !states.isEmpty {
                    let wins = winsForDifficulty(difficulty)
                    let winRate = states.count > 0 ? Double(wins) / Double(states.count) * 100 : 0
                    let avgTime = averageSolveTimesByDifficulty[difficulty] ?? 0
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(difficulty.rawValue.capitalized)
                                .font(.subheadline)
                                .bold()
                            Spacer()
                            Text("\(states.count) games")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 16) {
                            Label(String(format: "%.0f%% win", winRate), systemImage: "trophy.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Label(formatTime(avgTime), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            let avgScore = states.reduce(0) { $0 + $1.score } / max(states.count, 1)
                            Label("Avg \(avgScore) pts", systemImage: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    // MARK: - Recent Games
    
    private var recentGamesSection: some View {
        let recentStates = myStates
            .compactMap { state -> (PlayerGameState, GameSession)? in
                guard let gid = state.gameSessionID, let game = gameMap[gid] else { return nil }
                return (state, game)
            }
            .sorted { ($0.1.completedAt ?? .distantPast) > ($1.1.completedAt ?? .distantPast) }
            .prefix(10)
        
        return Section("Recent Games") {
            ForEach(Array(recentStates), id: \.0.id) { state, game in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.difficulty.rawValue.capitalized)
                            .font(.subheadline)
                            .bold()
                        if let completed = game.completedAt {
                            Text(completed, style: .date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(state.score) pts")
                            .font(.subheadline)
                            .bold()
                        Text("\(state.correctGuesses)✓ \(state.incorrectGuesses)✗")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var myGameTimes: [TimeInterval] {
        myStates.compactMap { state in
            guard let gid = state.gameSessionID,
                  let game = gameMap[gid],
                  game.completedAt != nil else { return nil }
            // Use active play time if tracked, fall back to wall-clock for older games
            let time = game.activePlayTime > 0 ? game.activePlayTime : {
                guard let started = game.startedAt, let completed = game.completedAt else { return 0.0 }
                return completed.timeIntervalSince(started)
            }()
            return time > 0 ? time : nil
        }
    }
    
    private var fastestSolveTime: TimeInterval? {
        myGameTimes.min()
    }
    
    private var averageSolveTimesByDifficulty: [DifficultyLevel: TimeInterval] {
        var result: [DifficultyLevel: [TimeInterval]] = [:]
        for state in myStates {
            guard let gid = state.gameSessionID,
                  let game = gameMap[gid],
                  game.completedAt != nil else { continue }
            let time = game.activePlayTime > 0 ? game.activePlayTime : {
                guard let started = game.startedAt, let completed = game.completedAt else { return 0.0 }
                return completed.timeIntervalSince(started)
            }()
            guard time > 0 else { continue }
            result[game.difficulty, default: []].append(time)
        }
        return result.mapValues { times in
            times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)
        }
    }
    
    private func statesForDifficulty(_ difficulty: DifficultyLevel) -> [PlayerGameState] {
        let gameIDs = Set(completedGames.filter { $0.difficulty == difficulty }.map(\.id))
        return myStates.filter { gameIDs.contains($0.gameSessionID ?? UUID()) }
    }
    
    private func winsForDifficulty(_ difficulty: DifficultyLevel) -> Int {
        statesForDifficulty(difficulty).filter { $0.didWin == true }.count
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        ExtendedStatsView()
    }
    .modelContainer(for: [GameSession.self, PlayerGameState.self], inMemory: true)
}
