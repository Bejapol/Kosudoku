//
//  ViewsDailyChallengesView.swift
//  Kosudoku
//
//  Created by Paul Kim on 4/4/26.
//

import SwiftUI

struct DailyChallengesView: View {
    let profile: UserProfile
    var engagementManager = EngagementManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Login Streak & First Game Bonus Row
            HStack(spacing: 12) {
                // Login streak
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Day \(profile.loginStreak)")
                        .font(.subheadline)
                        .bold()
                    
                    if profile.loginStreak > 0 {
                        Text("\(String(format: "%.1f", profile.loginStreakMultiplier))x XP")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // First game bonus
                if profile.isFirstGameToday {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("2x XP next game!")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(6)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Bonus claimed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Level & XP Bar
            let progress = xpProgressInCurrentLevel(profile.totalXP)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Level \(profile.playerLevel)")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Text("\(progress.current) / \(progress.needed) XP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(progress.current) / CGFloat(max(progress.needed, 1)))
                    }
                }
                .frame(height: 8)
            }
            
            // Rank Tier
            let tier = profile.rankTier
            HStack(spacing: 6) {
                Image(systemName: tier.icon)
                    .foregroundColor(tier.color)
                Text(tier.displayName)
                    .font(.subheadline)
                    .bold()
                Text("\(profile.rankPoints) RP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Daily Challenges Header
            HStack {
                Text("Daily Challenges")
                    .font(.subheadline)
                    .bold()
                Spacer()
                let completedCount = engagementManager.dailyChallenges.filter { $0.isCompleted }.count
                Text("\(completedCount)/3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Daily Challenge Items
            ForEach(engagementManager.dailyChallenges) { challenge in
                ChallengeRow(
                    icon: challenge.type.icon,
                    title: challenge.type.displayName,
                    current: challenge.currentProgress,
                    target: challenge.type.targetValue,
                    reward: "+\(challenge.xpReward) XP",
                    isCompleted: challenge.isCompleted
                )
            }
            
            // Weekly Challenge
            if let weekly = engagementManager.weeklyChallenge {
                Divider()
                
                HStack {
                    Text("Weekly Challenge")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Text(daysUntilReset)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ChallengeRow(
                    icon: weekly.type.icon,
                    title: weekly.type.displayName,
                    current: weekly.currentProgress,
                    target: weekly.type.targetValue,
                    reward: "+\(weekly.xpReward) XP",
                    isCompleted: weekly.isCompleted
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var daysUntilReset: String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // Sunday = 1, Monday = 2, ..., Saturday = 7
        // Reset on Monday (weekday 2)
        let daysLeft = (9 - weekday) % 7 // days until next Monday
        if daysLeft == 0 {
            return "Resets today"
        } else if daysLeft == 1 {
            return "Resets tomorrow"
        }
        return "Resets in \(daysLeft) days"
    }
}

struct ChallengeRow: View {
    let icon: String
    let title: String
    let current: Int
    let target: Int
    let reward: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                .foregroundColor(isCompleted ? .green : .blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                
                if target > 1 && !isCompleted {
                    ProgressView(value: Double(current), total: Double(target))
                        .tint(.blue)
                }
            }
            
            Spacer()
            
            if !isCompleted && target > 1 {
                Text("\(current)/\(target)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(reward)
                .font(.caption2)
                .bold()
                .foregroundColor(isCompleted ? .green : .orange)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Rank Tier Badge (reusable in leaderboard, lobby, etc.)

struct RankTierBadge: View {
    let tier: RankTier
    var showLabel: Bool = true
    var size: CGFloat = 16
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.icon)
                .font(.system(size: size))
                .foregroundColor(tier.color)
            
            if showLabel {
                Text(tier.displayName)
                    .font(.caption)
                    .foregroundColor(tier.color)
            }
        }
    }
}
