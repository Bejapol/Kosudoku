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
    @State private var showingColorPicker = false
    
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
                    }
                    
                    Section("My Goodies") {
                        if profile.hasCustomColor,
                           let colorRaw = profile.customColorRawValue,
                           let color = PlayerColor(rawValue: colorRaw) {
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 24, height: 24)
                                Text("Custom Game Color")
                                Spacer()
                                Button("Change") {
                                    showingColorPicker = true
                                }
                                .font(.subheadline)
                            }
                        } else {
                            HStack {
                                Image(systemName: "storefront.fill")
                                    .foregroundColor(.secondary)
                                Text("Visit the Store to customize your game experience")
                                    .font(.subheadline)
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
            .sheet(isPresented: $showingColorPicker) {
                if let profile = currentProfile {
                    ColorPickerSheet(profile: profile)
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

/// Sheet for changing the custom game color from the profile
private struct ColorPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var cloudKitService = CloudKitService.shared
    let profile: UserProfile
    @State private var selectedColor: PlayerColor?
    @State private var isSaving = false
    
    private var currentColor: PlayerColor? {
        guard let raw = profile.customColorRawValue else { return nil }
        return PlayerColor(rawValue: raw)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Choose your game color")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    ForEach(PlayerColor.allCases, id: \.rawValue) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 48, height: 48)
                                
                                if currentColor == color && selectedColor == nil {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                } else if selectedColor == color {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                    .frame(width: 54, height: 54)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if let selected = selectedColor, selected != currentColor {
                    Button {
                        saveColor(selected)
                    } label: {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Change Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func saveColor(_ color: PlayerColor) {
        isSaving = true
        profile.customColorRawValue = color.rawValue
        try? modelContext.save()
        
        Task {
            try? await cloudKitService.saveUserProfile(profile)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
