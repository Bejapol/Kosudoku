//
//  ViewsAchievementsView.swift
//  Kosudoku
//
//  Created by Paul Kim on 4/4/26.
//

import SwiftUI

struct AchievementsView: View {
    let profile: UserProfile
    
    var body: some View {
        List {
            ForEach(AchievementCategory.allCases, id: \.rawValue) { category in
                Section(category.displayName) {
                    let achievements = Achievement.allCases.filter { $0.category == category }
                    ForEach(achievements) { achievement in
                        AchievementRow(
                            achievement: achievement,
                            isUnlocked: profile.hasAchievement(achievement)
                        )
                    }
                }
            }
            
            // Level Milestones Section
            Section("Level Milestones") {
                ForEach(LevelMilestone.milestones, id: \.level) { milestone in
                    HStack(spacing: 12) {
                        let isUnlocked = profile.playerLevel >= milestone.level
                        
                        Image(systemName: isUnlocked ? "gift.fill" : "lock.fill")
                            .font(.title3)
                            .foregroundColor(isUnlocked ? .green : .gray)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Level \(milestone.level)")
                                .font(.subheadline)
                                .bold()
                            Text(milestone.rewardDescription)
                                .font(.caption)
                                .foregroundColor(isUnlocked ? .primary : .secondary)
                        }
                        
                        Spacer()
                        
                        if isUnlocked {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .opacity(profile.playerLevel >= milestone.level ? 1.0 : 0.6)
                }
            }
        }
        .navigationTitle("Achievements")
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    let isUnlocked: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isUnlocked ? achievement.icon : "questionmark.circle")
                .font(.title3)
                .foregroundColor(isUnlocked ? .blue : .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isUnlocked ? achievement.displayName : "???")
                    .font(.subheadline)
                    .bold()
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .opacity(isUnlocked ? 1.0 : 0.5)
    }
}
