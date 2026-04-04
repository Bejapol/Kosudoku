//
//  ProfileSetupView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct ProfileSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var displayName = ""
    @State private var profilePhotoData: Data?
    @State private var cloudKitService = CloudKitService.shared
    @State private var isCreating = false
    @State private var errorMessage: String?
    @Query private var existingProfiles: [UserProfile]
    
    var body: some View {
        NavigationStack {
            Form {
                // Show existing profiles if any
                if !existingProfiles.isEmpty {
                    Section("Existing Profiles") {
                        ForEach(existingProfiles) { profile in
                            Button {
                                Task {
                                    await loadExistingProfile(profile)
                                }
                            } label: {
                                HStack {
                                    ProfilePhotoView(
                                        imageData: profile.avatarImageData,
                                        displayName: profile.displayName,
                                        size: 44
                                    )
                                    
                                    VStack(alignment: .leading) {
                                        Text(profile.displayName)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("@\(profile.username)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("Sign In")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    // Only show profile creation when no profile exists
                    
                    // Profile photo section
                    Section {
                        HStack {
                            Spacer()
                            ProfilePhotoPicker(
                                imageData: $profilePhotoData,
                                size: 120,
                                displayName: displayName
                            )
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("New Profile Photo")
                    } footer: {
                        Text("Tap to add a photo or we'll generate one from your initials")
                    }
                    
                    Section("New Profile Information") {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                        
                        TextField("Display Name", text: $displayName)
                            .textContentType(.name)
                    }
                    
                    Section {
                        Text("Your username is how other players will find you. Your display name is what they'll see in games.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(existingProfiles.isEmpty ? "Create Profile" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !existingProfiles.isEmpty {
                        Button("Cancel") {
                            dismiss()
                        }
                        .disabled(isCreating)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if existingProfiles.isEmpty {
                        Button("Create") {
                            Task {
                                await createProfile()
                            }
                        }
                        .disabled(username.isEmpty || displayName.isEmpty || isCreating)
                    }
                }
            }
            .overlay {
                if isCreating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            }
        }
    }
    
    private func loadExistingProfile(_ profile: UserProfile) async {
        isCreating = true
        errorMessage = nil
        
        do {
            // Re-authenticate with CloudKit
            try await cloudKitService.requestPermissions()
            try await cloudKitService.authenticateUser()
            
            // Restore the existing profile
            cloudKitService.currentUserProfile = profile
            cloudKitService.isAuthenticated = true
            
            isCreating = false
            dismiss()
        } catch {
            errorMessage = "Failed to authenticate: \(error.localizedDescription)"
            isCreating = false
        }
    }
    
    private func createProfile() async {
        isCreating = true
        errorMessage = nil
        
        do {
            // Re-authenticate with CloudKit (in case they signed out)
            try await cloudKitService.requestPermissions()
            try await cloudKitService.authenticateUser()
            
            // Create profile WITHOUT cloudKitRecordName - let CloudKit assign it
            let profile = UserProfile(
                username: username,
                displayName: displayName,
                cloudKitRecordName: nil  // Don't pre-populate this!
            )
            
            // Add profile photo if selected
            profile.avatarImageData = profilePhotoData
            
            // Save locally first
            modelContext.insert(profile)
            try modelContext.save()
            
            // Then save to CloudKit (will assign the cloudKitRecordName)
            try await cloudKitService.saveUserProfile(profile)
            
            // Save again to persist the CloudKit record name
            try modelContext.save()
            
            // Update CloudKit service
            cloudKitService.currentUserProfile = profile
            cloudKitService.isAuthenticated = true
            
            // Request discoverability so contacts can find this user
            await cloudKitService.requestDiscoverability()
            
            isCreating = false
            dismiss()
        } catch {
            errorMessage = "Failed to create profile: \(error.localizedDescription)"
            isCreating = false
        }
    }
}

#Preview {
    ProfileSetupView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
