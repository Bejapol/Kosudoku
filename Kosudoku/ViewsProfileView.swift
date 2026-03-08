//
//  ProfileView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var cloudKitService = CloudKitService.shared
    @Query private var profiles: [UserProfile]
    @State private var showingEditProfile = false
    @State private var showingSignOutConfirmation = false
    
    var currentProfile: UserProfile? {
        // First check if CloudKit service has a current profile set
        if let currentProfile = cloudKitService.currentUserProfile {
            return currentProfile
        }
        // Otherwise, use the first profile (assumes one profile per device)
        return profiles.first
    }
    
    var body: some View {
        NavigationStack {
            List {
                if let profile = currentProfile {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProfilePhotoView(
                                    imageData: profile.avatarImageData,
                                    displayName: profile.displayName,
                                    size: 80
                                )
                                
                                Text(profile.displayName)
                                    .font(.title2)
                                    .bold()
                                
                                Text("@\(profile.username)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical)
                            Spacer()
                        }
                    }
                    
                    Section("Statistics") {
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
                    }
                    
                    Section("Account") {
                        Button("Edit Profile") {
                            showingEditProfile = true
                        }
                        
                        Button("Sign Out", role: .destructive) {
                            showingSignOutConfirmation = true
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Profile",
                        systemImage: "person.slash",
                        description: Text("Unable to load profile")
                    )
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingEditProfile) {
                if let profile = currentProfile {
                    EditProfileView(profile: profile)
                }
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Profile Data", role: .destructive) {
                    signOutAndDeleteData()
                }
                Button("Sign Out (Keep Data)", role: .destructive) {
                    signOutKeepData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Choose how you want to sign out. Deleting profile data will remove your local profile but won't affect your CloudKit data.")
            }
        }
    }
    
    private func signOutAndDeleteData() {
        // Set signed-out flag first to prevent auto-reload
        cloudKitService.isSignedOut = true
        
        // Clear CloudKit service state
        cloudKitService.isAuthenticated = false
        cloudKitService.currentUserProfile = nil
        cloudKitService.currentUserRecordName = nil
        
        // Delete all local profiles
        for profile in profiles {
            modelContext.delete(profile)
        }
        
        // Save the deletion
        try? modelContext.save()
    }
    
    private func signOutKeepData() {
        // Set signed-out flag to prevent auto-reload
        cloudKitService.isSignedOut = true
        
        // Just clear the CloudKit service state
        // Profile data remains in local database
        cloudKitService.isAuthenticated = false
        cloudKitService.currentUserProfile = nil
        cloudKitService.currentUserRecordName = nil
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
