//
//  UserProfile.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var username: String
    var displayName: String
    var avatarImageData: Data?
    var createdAt: Date
    var totalScore: Int
    var gamesPlayed: Int
    var gamesWon: Int
    var quickets: Int = 5
    
    // CloudKit user identifier
    var cloudKitRecordName: String?
    
    init(username: String, displayName: String, cloudKitRecordName: String? = nil) {
        self.id = UUID()
        self.username = username
        self.displayName = displayName
        self.createdAt = Date()
        self.totalScore = 0
        self.gamesPlayed = 0
        self.gamesWon = 0
        self.quickets = 5
        self.cloudKitRecordName = cloudKitRecordName
    }
}
