//
//  Friendship.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation
import SwiftData

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case blocked
}

@Model
final class Friendship {
    @Attribute(.unique) var id: UUID
    var userRecordName: String // Changed from relationship to simple property
    var friendRecordName: String // CloudKit record name of the friend
    var friendUsername: String
    var friendDisplayName: String
    var status: FriendshipStatus
    var createdAt: Date
    var acceptedAt: Date?
    var cloudKitRecordName: String? // CloudKit record name for updating/deleting
    
    init(userRecordName: String, friendRecordName: String, friendUsername: String, friendDisplayName: String, status: FriendshipStatus = .pending) {
        self.id = UUID()
        self.userRecordName = userRecordName
        self.friendRecordName = friendRecordName
        self.friendUsername = friendUsername
        self.friendDisplayName = friendDisplayName
        self.status = status
        self.createdAt = Date()
    }
}
