//
//  ContactsInviteView.swift
//  Kosudoku
//
//  Created by Paul Kim.
//

import SwiftUI
import SwiftData
import Contacts
import CloudKit

/// A contact discovered via CloudKit who also uses Kosudoku
struct DiscoveredContact: Identifiable {
    let id: String // CNContact identifier
    let contact: CNContact
    let userRecordName: String // CloudKit ownerRecordName for friend request
    let kosudokuUsername: String
    let kosudokuDisplayName: String
    var isAlreadyFriend: Bool
    var friendRequestSent: Bool
}

/// View for discovering friends from device contacts and inviting non-users
struct ContactsInviteView: View {
    let friendships: [Friendship]
    @Environment(\.modelContext) private var modelContext
    @State private var authStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    @State private var allContacts: [CNContact] = []
    @State private var discoveredUsers: [DiscoveredContact] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var sentRequestIDs: Set<String> = []
    
    private let contactStore = CNContactStore()
    private let cloudKitService = CloudKitService.shared
    
    /// App Store link (placeholder until app is published)
    private let appStoreURL = URL(string: "https://apps.apple.com/app/kosudoku/id0000000000")!
    
    /// Contact identifiers of users who are on Kosudoku
    private var discoveredContactIDs: Set<String> {
        Set(discoveredUsers.map(\.id))
    }
    
    /// Contacts who are NOT on Kosudoku (for the invite section)
    private var nonKosudokuContacts: [CNContact] {
        allContacts.filter { !discoveredContactIDs.contains($0.identifier) }
    }
    
    var body: some View {
        Group {
            if authStatus == .authorized {
                contactListContent
            } else if authStatus == .denied || authStatus == .restricted {
                accessDeniedView
            } else {
                requestAccessView
            }
        }
        .navigationTitle("Find Friends")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if authStatus == .authorized {
                await loadContactsAndDiscover()
            }
        }
    }
    
    // MARK: - Main Content
    
    private var contactListContent: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Finding friends...")
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                }
            } else {
                if !discoveredUsers.isEmpty {
                    Section("Friends on Kosudoku") {
                        ForEach(discoveredUsers) { user in
                            DiscoveredUserRow(
                                user: user,
                                onAddFriend: {
                                    Task { await sendFriendRequest(to: user) }
                                }
                            )
                        }
                    }
                }
                
                if !nonKosudokuContacts.isEmpty {
                    Section("Invite to Kosudoku") {
                        ForEach(nonKosudokuContacts, id: \.identifier) { contact in
                            InviteContactRow(contact: contact, appStoreURL: appStoreURL)
                        }
                    }
                }
                
                if discoveredUsers.isEmpty && nonKosudokuContacts.isEmpty {
                    Section {
                        Text("No contacts found.")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Permission Views
    
    private var requestAccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Find Friends from Contacts")
                .font(.title2)
                .bold()
            
            Text("Allow Kosudoku to access your contacts to find friends who play the game and invite others to join.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Button("Allow Access") {
                Task {
                    await requestContactsAccess()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var accessDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Contacts Access Denied")
                .font(.title2)
                .bold()
            
            Text("To find friends from your contacts, enable Contacts access in Settings.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Data Loading
    
    private func requestContactsAccess() async {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            authStatus = granted ? .authorized : .denied
            if granted {
                await loadContactsAndDiscover()
            }
        } catch {
            authStatus = .denied
        }
    }
    
    private func loadContactsAndDiscover() async {
        isLoading = true
        errorMessage = nil
        
        // Fetch device contacts
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]
        
        do {
            let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
            fetchRequest.sortOrder = .givenName
            
            var contacts: [CNContact] = []
            try contactStore.enumerateContacts(with: fetchRequest) { contact, _ in
                // Only include contacts with a name
                if !contact.givenName.isEmpty || !contact.familyName.isEmpty {
                    contacts.append(contact)
                }
            }
            allContacts = contacts
        } catch {
            errorMessage = "Failed to load contacts: \(error.localizedDescription)"
            isLoading = false
            return
        }
        
        // Discover CloudKit users from contacts
        do {
            let identities = try await cloudKitService.discoverContactsUsingApp()
            
            // Build set of existing friend record names
            let currentUser = cloudKitService.currentUserRecordName ?? ""
            let friendRecordNames = Set(friendships.compactMap { friendship -> String? in
                if friendship.userRecordName == currentUser {
                    return friendship.friendRecordName
                } else if friendship.friendRecordName == currentUser {
                    return friendship.userRecordName
                }
                return nil
            })
            
            var discovered: [DiscoveredContact] = []
            
            for identity in identities {
                guard let userRecordID = identity.userRecordID else { continue }
                let ownerRecordName = userRecordID.recordName
                
                // Skip self
                if ownerRecordName == currentUser { continue }
                
                // Fetch this user's Kosudoku profile
                guard let profile = try? await cloudKitService.fetchUserProfileByOwner(ownerRecordName: ownerRecordName) else {
                    continue
                }
                
                // Match back to a device contact via contactIdentifiers (deprecated iOS 18, no replacement)
                let contactID = identity.contactIdentifiers.first ?? ""
                let matchedContact = allContacts.first { $0.identifier == contactID }
                
                // If we couldn't match a contact, create a placeholder
                let contact = matchedContact ?? CNContact()
                
                let isAlreadyFriend = friendRecordNames.contains(ownerRecordName)
                
                discovered.append(DiscoveredContact(
                    id: contactID.isEmpty ? ownerRecordName : contactID,
                    contact: contact,
                    userRecordName: ownerRecordName,
                    kosudokuUsername: profile.username,
                    kosudokuDisplayName: profile.displayName,
                    isAlreadyFriend: isAlreadyFriend,
                    friendRequestSent: false
                ))
            }
            
            discoveredUsers = discovered
        } catch {
            // Discovery failed — still show contacts for inviting
            print("CloudKit discovery failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Friend Request
    
    private func sendFriendRequest(to user: DiscoveredContact) async {
        guard let currentUser = cloudKitService.currentUserRecordName else { return }
        
        do {
            let ckRecordName = try await cloudKitService.sendFriendRequest(
                to: user.userRecordName,
                friendUsername: user.kosudokuUsername,
                friendDisplayName: user.kosudokuDisplayName
            )
            
            // Save locally
            let friendship = Friendship(
                userRecordName: currentUser,
                friendRecordName: user.userRecordName,
                friendUsername: user.kosudokuUsername,
                friendDisplayName: user.kosudokuDisplayName,
                status: .pending
            )
            friendship.cloudKitRecordName = ckRecordName
            modelContext.insert(friendship)
            try? modelContext.save()
            
            // Update UI
            sentRequestIDs.insert(user.id)
            if let index = discoveredUsers.firstIndex(where: { $0.id == user.id }) {
                discoveredUsers[index].friendRequestSent = true
            }
        } catch {
            print("Failed to send friend request: \(error.localizedDescription)")
        }
    }
}

// MARK: - Discovered User Row

struct DiscoveredUserRow: View {
    let user: DiscoveredContact
    let onAddFriend: () -> Void
    
    private var contactName: String {
        let given = user.contact.givenName
        let family = user.contact.familyName
        let fullName = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        return fullName.isEmpty ? user.kosudokuDisplayName : fullName
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let imageData = user.contact.thumbnailImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(user.kosudokuDisplayName.prefix(1))
                            .foregroundColor(.white)
                            .font(.headline)
                    }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(contactName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("@\(user.kosudokuUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action
            if user.isAlreadyFriend {
                Text("Friends")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
            } else if user.friendRequestSent {
                Text("Sent")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            } else {
                Button("Add Friend") {
                    onAddFriend()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Invite Contact Row

struct InviteContactRow: View {
    let contact: CNContact
    let appStoreURL: URL
    
    private var contactName: String {
        let fullName = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return fullName.isEmpty ? "Unknown" : fullName
    }
    
    private var phoneLabel: String? {
        guard let phone = contact.phoneNumbers.first else { return nil }
        return phone.value.stringValue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let imageData = contact.thumbnailImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(contactName.prefix(1))
                            .foregroundColor(.white)
                            .font(.headline)
                    }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(contactName)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let phone = phoneLabel {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            ShareLink(
                item: appStoreURL,
                subject: Text("Join me on Kosudoku!"),
                message: Text("Hey! I've been playing Kosudoku — it's a multiplayer Sudoku game. Join me!")
            ) {
                Text("Invite")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}
