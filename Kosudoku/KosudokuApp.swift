//
//  KosudokuApp.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // Handle incoming remote notifications (CloudKit subscriptions)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Convert keys to [String: Any] for our handler
        let info = userInfo.compactMapKeys { $0 as? String }
        Task { @MainActor in
            let handled = await ChatNotificationManager.shared.handleNotification(userInfo: info)
            completionHandler(handled ? .newData : .noData)
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // When app is in foreground: suppress system banner (our custom in-app banner handles it)
    // When app is in background: this method is NOT called, so iOS shows system notification normally
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Forward to our notification manager for in-app banner display
        let userInfo = notification.request.content.userInfo
        let info = userInfo.compactMapKeys { $0 as? String }
        _ = await ChatNotificationManager.shared.handleNotification(userInfo: info)
        // Return empty so iOS doesn't also show a system banner on top of ours
        return []
    }
    
    // Handle notification tap (future: deep-link to chat)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // Could navigate to the relevant chat in the future
    }
}

// Helper to convert [AnyHashable: Any] keys
private extension Dictionary where Key == AnyHashable {
    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
}

@main
struct KosudokuApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
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
    @State private var storeManager = StoreManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .task {
                    await authenticateUser()
                    // Register for remote notifications so CloudKit subscriptions can deliver push alerts
                    UIApplication.shared.registerForRemoteNotifications()
                    // Request permission for visible push notifications
                    await ChatNotificationManager.shared.requestNotificationPermission()
                    // Start StoreKit transaction listener and load products
                    storeManager.startTransactionListener()
                    await storeManager.loadProducts()
                    // Start online status heartbeat
                    OnlineStatusService.shared.startHeartbeat()
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

