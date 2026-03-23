//
//  EditProfileView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile
    @State private var displayName: String
    @State private var profilePhotoData: Data?
    @State private var isSaving = false
    private let cloudKitService = CloudKitService.shared
    
    init(profile: UserProfile) {
        self.profile = profile
        _displayName = State(initialValue: profile.displayName)
        _profilePhotoData = State(initialValue: profile.avatarImageData)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile photo section
                Section {
                    HStack {
                        Spacer()
                        ProfilePhotoPicker(
                            imageData: $profilePhotoData,
                            size: 120,
                            displayName: displayName.isEmpty ? profile.displayName : displayName
                        )
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Profile Photo")
                } footer: {
                    Text("Tap to change your photo or remove it to use initials")
                }
                
                Section("Profile Information") {
                    TextField("Display Name", text: $displayName)
                }
                
                Section {
                    Text("Username: @\(profile.username)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                // Option to remove photo
                if profilePhotoData != nil {
                    Section {
                        Button("Remove Photo", role: .destructive) {
                            profilePhotoData = nil
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(displayName.isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            }
        }
    }
    
    private func saveProfile() async {
        isSaving = true
        
        // Update the local SwiftData model
        profile.displayName = displayName
        profile.avatarImageData = profilePhotoData
        
        // Sync to CloudKit in the background — don't block dismissal on it
        do {
            try await cloudKitService.saveUserProfile(profile)
        } catch {
            print("Error syncing profile to CloudKit: \(error)")
        }
        
        isSaving = false
        dismiss()
    }
}

#Preview {
    EditProfileView(profile: UserProfile(username: "testuser", displayName: "Test User"))
        .modelContainer(for: UserProfile.self, inMemory: true)
}
