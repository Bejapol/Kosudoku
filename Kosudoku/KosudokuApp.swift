//
//  KosudokuApp.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData

@main
struct KosudokuApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            GameSession.self,
            PlayerGameState.self,
            ChatMessage.self,
            Friendship.self,
            GroupChat.self
        ])
        
        // For development: change the version number if you need to reset the database
        let appSupportURL = URL.applicationSupportDirectory
            .appending(path: "Kosudoku")
            .appending(path: "v1.store") // ← Increment this to reset the database
        
        let modelConfiguration = ModelConfiguration(
            url: appSupportURL,
            cloudKitDatabase: .none
        )
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ ModelContainer created successfully")
            return container
        } catch {
            // If it fails, try with in-memory storage as fallback
            print("⚠️ Failed to create persistent storage: \(error)")
            print("🔄 Attempting in-memory container...")
            
            do {
                let inMemoryConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                
                let container = try ModelContainer(
                    for: schema,
                    configurations: [inMemoryConfiguration]
                )
                print("✅ In-memory container created")
                return container
            } catch {
                fatalError("Unable to create ModelContainer: \(error)")
            }
        }
    }()
    
    @State private var cloudKitService = CloudKitService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)  // ← Moved here from WindowGroup
                .task {
                    await authenticateUser()
                }
        }
    }
    
    private func authenticateUser() async {
        do {
            try await cloudKitService.requestPermissions()
            try await cloudKitService.authenticateUser()
            print("✅ CloudKit authenticated")
        } catch {
            print("⚠️ CloudKit authentication failed: \(error.localizedDescription)")
        }
    }
}

