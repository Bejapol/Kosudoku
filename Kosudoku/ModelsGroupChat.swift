//
//  GroupChat.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/7/26.
//

import Foundation
import SwiftData

@Model
final class GroupChat {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var creatorRecordName: String
    var memberRecordNames: [String] // CloudKit record names of members
    var cloudKitRecordName: String?
    
    init(name: String, creatorRecordName: String, memberRecordNames: [String] = []) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.creatorRecordName = creatorRecordName
        self.memberRecordNames = memberRecordNames
    }
}
