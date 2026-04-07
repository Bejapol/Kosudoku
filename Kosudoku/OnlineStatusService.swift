//
//  OnlineStatusService.swift
//  Kosudoku
//
//  Manages online/offline status tracking and provides a reusable indicator view.
//

import SwiftUI

/// Threshold in seconds: users active within this window are considered "online"
private let onlineThreshold: TimeInterval = 120 // 2 minutes

/// Shared service that caches online status for other users and periodically refreshes.
@Observable
@MainActor
class OnlineStatusService {
    static let shared = OnlineStatusService()
    
    /// Cached last-active dates keyed by ownerRecordName
    private(set) var lastActiveDates: [String: Date] = [:]
    
    /// Owner record names we're currently tracking
    private var trackedUsers: Set<String> = []
    
    private var refreshTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    
    /// When true, online status refresh is paused (e.g. during active gameplay)
    private(set) var isPaused = false
    
    private let cloudKit = CloudKitService.shared
    
    private init() {}
    
    // MARK: - Public API
    
    /// Register owner record names to track. Call this whenever the set of visible users changes.
    func track(ownerRecordNames: [String]) {
        let newNames = Set(ownerRecordNames)
        trackedUsers.formUnion(newNames)
        startRefreshingIfNeeded()
    }
    
    /// Check if a user is currently online (active within the threshold)
    func isOnline(ownerRecordName: String) -> Bool {
        guard let lastActive = lastActiveDates[ownerRecordName] else { return false }
        return Date().timeIntervalSince(lastActive) < onlineThreshold
    }
    
    /// Start the heartbeat that updates the current user's lastActiveDate
    func startHeartbeat() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task {
            while !Task.isCancelled {
                await cloudKit.updateLastActiveDate()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
    
    /// Stop the heartbeat
    func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }
    
    /// Pause online status refreshes (call when entering active gameplay)
    func pause() {
        isPaused = true
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    /// Resume online status refreshes (call when leaving gameplay)
    func resume() {
        isPaused = false
        startRefreshingIfNeeded()
    }
    
    /// Manually refresh status for all tracked users
    func refresh() async {
        guard !trackedUsers.isEmpty, !isPaused else { return }
        let dates = await cloudKit.fetchOnlineStatus(ownerRecordNames: Array(trackedUsers))
        for (key, value) in dates {
            lastActiveDates[key] = value
        }
    }
    
    // MARK: - Private
    
    private func startRefreshingIfNeeded() {
        guard refreshTask == nil, !isPaused else { return }
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}

// MARK: - Online Status Indicator View

/// A small LED circle indicating online (green) or offline (gray) status.
struct OnlineStatusIndicator: View {
    let ownerRecordName: String
    var size: CGFloat = 8
    
    @State private var onlineService = OnlineStatusService.shared
    
    private var isOnline: Bool {
        onlineService.isOnline(ownerRecordName: ownerRecordName)
    }
    
    var body: some View {
        Circle()
            .fill(isOnline ? Color.green : Color.gray.opacity(0.5))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color(.systemBackground), lineWidth: 1.5)
            )
            .onAppear {
                onlineService.track(ownerRecordNames: [ownerRecordName])
            }
    }
}
