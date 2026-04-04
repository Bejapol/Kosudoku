//
//  PlayerProfileView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/24/26.
//

import SwiftUI

/// Displays another player's profile, fetched from CloudKit by their owner record name
struct PlayerProfileView: View {
    let ownerRecordName: String
    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var cloudKitService = CloudKitService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading profile...")
                } else if let profile {
                    List {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    ProfilePhotoView(
                                        imageData: profile.avatarImageData,
                                        displayName: profile.displayName,
                                        size: 80,
                                        profileFrame: profile.activeProfileFrame
                                    )
                                    
                                    HStack(spacing: 6) {
                                        Text(profile.displayName)
                                            .font(.title2)
                                            .bold()
                                        
                                        if profile.activeTitleBadge != .none {
                                            Text(profile.activeTitleBadge.displayName)
                                                .font(.caption)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.purple.opacity(0.15))
                                                .foregroundColor(.purple)
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    Text("@\(profile.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical)
                                Spacer()
                            }
                        }
                        
                        // Level & Rank
                        Section("Level & Rank") {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Level \(profile.playerLevel)")
                                    .font(.headline)
                                Spacer()
                                Text("\(profile.totalXP) XP")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                let tier = profile.rankTier
                                Image(systemName: tier.icon)
                                    .foregroundColor(tier.color)
                                Text(tier.displayName)
                                    .font(.headline)
                                Spacer()
                                Text("\(profile.rankPoints) RP")
                                    .bold()
                                    .foregroundColor(tier.color)
                            }
                        }
                        
                        Section("Statistics") {
                            HStack {
                                Label("Quickets", systemImage: "ticket.fill")
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("\(profile.quickets)")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.orange)
                            }
                            
                            HStack {
                                Text("Total Score")
                                Spacer()
                                Text("\(profile.totalScore)")
                                    .bold()
                            }
                            
                            HStack {
                                Text("Games Played")
                                Spacer()
                                Text("\(profile.gamesPlayed)")
                                    .bold()
                            }
                            
                            HStack {
                                Text("Games Won")
                                Spacer()
                                Text("\(profile.gamesWon)")
                                    .bold()
                            }
                            
                            HStack {
                                Text("Win Rate")
                                Spacer()
                                if profile.gamesPlayed > 0 {
                                    Text("\(Int(Double(profile.gamesWon) / Double(profile.gamesPlayed) * 100))%")
                                        .bold()
                                } else {
                                    Text("N/A")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Label("Win Streak", systemImage: "flame.fill")
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("\(profile.currentWinStreak)")
                                    .bold()
                            }
                            
                            HStack {
                                Text("Best Streak")
                                Spacer()
                                Text("\(profile.bestWinStreak)")
                                    .bold()
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Profile Not Found",
                        systemImage: "person.slash",
                        description: Text("Unable to load this player's profile")
                    )
                }
            }
            .navigationTitle("Player Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadProfile()
            }
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        // If this is the current user, use their local profile
        if ownerRecordName == cloudKitService.currentUserRecordName,
           let currentProfile = cloudKitService.currentUserProfile {
            profile = currentProfile
            return
        }
        
        // Fetch from CloudKit
        do {
            profile = try await cloudKitService.fetchUserProfileByOwner(ownerRecordName: ownerRecordName)
        } catch {
            print("Failed to load player profile: \(error)")
        }
    }
}
