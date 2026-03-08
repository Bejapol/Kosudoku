# CloudKit Schema - Copy/Paste Checklist

Use this checklist to ensure you've created everything correctly. Check off each item as you complete it!

## Navigation Checklist

- [ ] Opened [icloud.developer.apple.com/dashboard](https://icloud.developer.apple.com/dashboard/)
- [ ] Signed in with Apple Developer account
- [ ] Selected container: `iCloud.com.yourname.Kosudoku`
- [ ] Clicked **Schema** tab
- [ ] Expanded **Development** environment
- [ ] Selected **Public Database**

---

## Record Type 1: UserProfile

- [ ] Created record type named `UserProfile` (exact spelling, capital U and P)

### Fields (7 total)
- [ ] `username` - Type: **String**
- [ ] `displayName` - Type: **String**
- [ ] `totalScore` - Type: **Int(64)**
- [ ] `gamesPlayed` - Type: **Int(64)**
- [ ] `gamesWon` - Type: **Int(64)**
- [ ] `avatar` - Type: **Asset**
- [ ] `createdAt` - Type: **Date/Time**

### Indexes (2 total)
- [ ] `username` - **Queryable** (and optionally **Searchable**)
- [ ] `displayName` - **Queryable**

---

## Record Type 2: GameSession

- [ ] Created record type named `GameSession` (exact spelling, capital G and S)

### Fields (8 total)
- [ ] `hostRecordName` - Type: **String**
- [ ] `difficulty` - Type: **String**
- [ ] `puzzleData` - Type: **String**
- [ ] `solutionData` - Type: **String**
- [ ] `status` - Type: **String**
- [ ] `createdAt` - Type: **Date/Time**
- [ ] `startedAt` - Type: **Date/Time**
- [ ] `completedAt` - Type: **Date/Time**

### Indexes (2 total)
- [ ] `status` - **Queryable**
- [ ] `createdAt` - **Sortable** (and optionally **Queryable**)

---

## Record Type 3: PlayerGameState

- [ ] Created record type named `PlayerGameState` (exact spelling, capital P, G, S)

### Fields (10 total)
- [ ] `playerRecordName` - Type: **String**
- [ ] `playerUsername` - Type: **String**
- [ ] `gameSession` - Type: **Reference**
  - [ ] Target: **GameSession**
  - [ ] Action: **Cascade** (or "Delete Self")
- [ ] `currentBoardData` - Type: **String**
- [ ] `score` - Type: **Int(64)**
- [ ] `correctGuesses` - Type: **Int(64)**
- [ ] `incorrectGuesses` - Type: **Int(64)**
- [ ] `cellsCompleted` - Type: **String List** (or [String] or String with "Multiple Values")
- [ ] `joinedAt` - Type: **Date/Time**
- [ ] `lastMoveAt` - Type: **Date/Time**

### Indexes (1 total)
- [ ] `playerRecordName` - **Queryable**

---

## Record Type 4: ChatMessage

- [ ] Created record type named `ChatMessage` (exact spelling, capital C and M)

### Fields (7 total)
- [ ] `senderRecordName` - Type: **String**
- [ ] `senderUsername` - Type: **String**
- [ ] `content` - Type: **String**
- [ ] `messageType` - Type: **String**
- [ ] `timestamp` - Type: **Date/Time**
- [ ] `gameSession` - Type: **Reference**
  - [ ] Target: **GameSession**
  - [ ] Action: **Cascade**
- [ ] `groupChatID` - Type: **String**

### Indexes (2 total)
- [ ] `timestamp` - **Sortable** (and optionally **Queryable**)
- [ ] `groupChatID` - **Queryable**

---

## Record Type 5: Friendship

- [ ] Created record type named `Friendship` (exact spelling, capital F)

### Fields (7 total)
- [ ] `userRecordName` - Type: **String**
- [ ] `friendRecordName` - Type: **String**
- [ ] `friendUsername` - Type: **String**
- [ ] `friendDisplayName` - Type: **String**
- [ ] `status` - Type: **String**
- [ ] `createdAt` - Type: **Date/Time**
- [ ] `acceptedAt` - Type: **Date/Time**

### Indexes (3 total)
- [ ] `userRecordName` - **Queryable**
- [ ] `friendRecordName` - **Queryable**
- [ ] `status` - **Queryable**

---

## Record Type 6: GroupChat

- [ ] Created record type named `GroupChat` (exact spelling, capital G and C)

### Fields (4 total)
- [ ] `name` - Type: **String**
- [ ] `creatorRecordName` - Type: **String**
- [ ] `memberRecordNames` - Type: **String List** (or [String] or String with "Multiple Values")
- [ ] `createdAt` - Type: **Date/Time**

### Indexes
- [ ] No indexes needed for GroupChat

---

## Final Verification

- [ ] All 6 record types show up in Schema → Development → Public Database → Record Types
- [ ] Total of 43 fields across all record types
- [ ] Total of 10 indexes across all record types
- [ ] No red error indicators in CloudKit Dashboard
- [ ] Can switch to **Data** tab and see all 6 record types in dropdown

---

## Quick Totals for Verification

| Record Type | Fields | Indexes |
|-------------|--------|---------|
| UserProfile | 7 | 2 |
| GameSession | 8 | 2 |
| PlayerGameState | 10 | 1 |
| ChatMessage | 7 | 2 |
| Friendship | 7 | 3 |
| GroupChat | 4 | 0 |
| **TOTAL** | **43** | **10** |

---

## Common Field Type Names (Different Dashboard Versions)

If you can't find the exact type name listed above, try these alternatives:

| Our Name | Alternative Names |
|----------|-------------------|
| String | Text, String, NSString |
| Int(64) | Int64, Integer, Long, Number |
| Date/Time | DateTime, Date, Timestamp, NSDate |
| Asset | CKAsset, File, Binary |
| Reference | CKReference, Relationship, Link |
| String List | [String], Array<String>, List<String>, StringArray |

---

## Test Your Schema

After completing the checklist, verify by running this in Xcode:

```swift
import CloudKit

Task {
    let container = CKContainer.default()
    let database = container.publicCloudDatabase
    
    // Try to fetch a record type
    let query = CKQuery(recordType: "UserProfile", predicate: NSPredicate(value: false))
    do {
        let (results, _) = try await database.records(matching: query, desiredKeys: nil, resultsLimit: 1)
        print("✅ UserProfile record type exists!")
    } catch {
        print("❌ Error: \(error)")
    }
}
```

If this runs without "unknown record type" error, you're good!

---

## Still Having Issues?

### Issue: Can't create Reference field

**Fix:**
1. Make sure target record type (GameSession) exists FIRST
2. Then create the reference field
3. If field already exists, edit it to set target

### Issue: Can't create String List

**Try these in order:**
1. Look for "String List" in type dropdown
2. Look for "[String]" in type dropdown
3. Create String field, then look for "Allow Multiple Values" checkbox
4. Create String field, then look for "Type: Array" option in properties

### Issue: Indexes not appearing

**Try these:**
1. Make sure you saved the record type first
2. Indexes might be in separate section/tab
3. Try refreshing the page
4. Create the record type, then come back to add indexes

### Issue: Changes not saving

**CloudKit auto-saves!** But:
1. Look for "Save" button at top
2. Click it if you see it
3. Look for green checkmark or "Saved" notification
4. Refresh page to confirm changes persist

---

## Emergency: Start Over

If you made mistakes:

1. Go to Schema → Development → Public Database
2. Right-click (or control-click) each record type
3. Select "Delete"
4. Confirm deletion
5. Start fresh with checklist

**OR**

1. In CloudKit Dashboard, look for "Reset Development Environment"
2. This nukes everything and starts fresh
3. ⚠️ **Warning**: Deletes all development data!

---

## Success Indicators

You'll know you're done when:

✅ All checkboxes above are checked
✅ No error messages in CloudKit Dashboard
✅ Data tab shows all 6 record types
✅ App builds and runs without CloudKit errors
✅ Can create user profile in app

---

**Print this checklist and check items off as you go!** 📝
