//
//  ContentView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var cloudKitService = CloudKitService.shared
    @State private var showingProfileSetup = false
    @State private var selectedTab = 0
    @Query private var profiles: [UserProfile]
    @Query private var gameSessions: [GameSession]
    
    private var waitingGamesCount: Int {
        gameSessions.filter { $0.status == .waiting }.count
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
                .badge(waitingGamesCount > 0 ? waitingGamesCount : 0)
            
            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(1)
            
            ChatsView()
                .tabItem {
                    Label("Chats", systemImage: "message.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .sheet(isPresented: $showingProfileSetup) {
            ProfileSetupView()
                .interactiveDismissDisabled(profiles.isEmpty && cloudKitService.currentUserProfile == nil)
        }
        .task {
            await checkProfileSetup()
        }
        .onChange(of: cloudKitService.currentUserProfile) { _, newValue in
            // Re-check profile setup when current profile changes
            if newValue == nil {
                Task {
                    await checkProfileSetup()
                }
            }
        }
    }
    
    private func checkProfileSetup() async {
        // Wait a bit for the view to load
        try? await Task.sleep(for: .milliseconds(100))
        
        // If user is signed out, show profile setup
        if cloudKitService.isSignedOut {
            showingProfileSetup = true
            return
        }
        
        // Check if user is authenticated
        guard cloudKitService.isAuthenticated else {
            return
        }
        
        // Check if there's a profile in CloudKit service
        if cloudKitService.currentUserProfile != nil {
            return
        }
        
        // Check if there's a local profile
        if let firstProfile = profiles.first {
            // Found a local profile, use it
            cloudKitService.currentUserProfile = firstProfile
            return
        }
        
        // No profile found, show setup
        showingProfileSetup = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
