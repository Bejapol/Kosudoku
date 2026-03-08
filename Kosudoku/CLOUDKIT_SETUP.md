# CloudKit Setup Guide

This guide will help you set up the CloudKit schema for Kosudoku.

> **🚀 QUICK START: Import Schema Automatically**
> 
> Instead of creating fields manually, you can import the entire schema at once!
> See **[CLOUDKIT_IMPORT_GUIDE.md](CLOUDKIT_IMPORT_GUIDE.md)** for instructions.
>
> The schema file is included: **[cloudkit-schema.json](cloudkit-schema.json)**

> **📖 Having trouble with the Dashboard interface?** Check out these guides:
> - **[CLOUDKIT_IMPORT_GUIDE.md](CLOUDKIT_IMPORT_GUIDE.md)** - Import schema automatically ⭐
> - **[CLOUDKIT_VISUAL_GUIDE.md](CLOUDKIT_VISUAL_GUIDE.md)** - Simplified manual setup
> - **[CLOUDKIT_DASHBOARD_GUIDE.md](CLOUDKIT_DASHBOARD_GUIDE.md)** - Detailed troubleshooting
> - **[CLOUDKIT_CHECKLIST.md](CLOUDKIT_CHECKLIST.md)** - Track manual setup progress

## Quick Setup Steps

### 1. Enable CloudKit in Xcode

1. Select your project in the Project Navigator
2. Select your app target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** button
5. Add **iCloud**
6. Check the **CloudKit** checkbox
7. Select or create a CloudKit container (usually `iCloud.com.yourcompany.Kosudoku`)

### 2. Enable Background Capabilities

1. Still in **Signing & Capabilities**
2. Click **+ Capability** button
3. Add **Background Modes**
4. Check:
   - **Remote notifications**
   - **Background fetch**

### 3. Set Up CloudKit Schema

Open the [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/):

1. Sign in with your Apple Developer account
2. Select your CloudKit container
3. Choose **Schema** → **Public Database** (for development)
4. Create the record types below

## Record Type Definitions

### UserProfile

**Indexes:**
- `username` - Queryable, Searchable
- `displayName` - Queryable

**Fields:**
```
username         : String    [Indexed, Queryable]
displayName      : String    [Queryable]
totalScore       : Int64
gamesPlayed      : Int64
gamesWon         : Int64
avatar           : Asset     [Optional]
createdAt        : Date/Time
```

### GameSession

**Indexes:**
- `status` - Queryable
- `createdAt` - Sortable

**Fields:**
```
hostRecordName   : String
difficulty       : String
puzzleData       : String
solutionData     : String
status           : String    [Indexed, Queryable]
createdAt        : Date/Time [Indexed, Sortable]
startedAt        : Date/Time [Optional]
completedAt      : Date/Time [Optional]
```

### PlayerGameState

**Indexes:**
- `playerRecordName` - Queryable
- `gameSession` - Reference

**Fields:**
```
playerRecordName   : String    [Indexed]
playerUsername     : String
gameSession        : Reference → GameSession [Cascade Delete]
currentBoardData   : String
score              : Int64
correctGuesses     : Int64
incorrectGuesses   : Int64
cellsCompleted     : List<String>
joinedAt           : Date/Time
lastMoveAt         : Date/Time [Optional]
```

### ChatMessage

**Indexes:**
- `timestamp` - Sortable
- `gameSession` - Reference (optional)
- `groupChatID` - Queryable (optional)

**Fields:**
```
senderRecordName : String
senderUsername   : String
content          : String
messageType      : String
timestamp        : Date/Time  [Indexed, Sortable]
gameSession      : Reference → GameSession [Optional, Cascade Delete]
groupChatID      : String     [Optional, Indexed]
```

### Friendship

**Indexes:**
- `userRecordName` - Queryable
- `friendRecordName` - Queryable
- `status` - Queryable

**Fields:**
```
userRecordName    : String    [Indexed, Queryable]
friendRecordName  : String    [Indexed, Queryable]
friendUsername    : String
friendDisplayName : String
status            : String    [Indexed, Queryable]
createdAt         : Date/Time
acceptedAt        : Date/Time [Optional]
```

### GroupChat

**Fields:**
```
name                : String
creatorRecordName   : String
memberRecordNames   : List<String>
createdAt           : Date/Time
```

## Setting Up Indexes

For each record type:

1. Click on the record type name
2. Click **Add Index**
3. Select the field to index
4. Choose index type:
   - **Queryable**: For searching and filtering
   - **Sortable**: For ordering results
   - **Searchable**: For text search (String fields only)

## Important Notes

### Public vs Private Database

- **Public Database**: Used for shared data (games, profiles, chat)
  - Accessible to all users
  - Requires user authentication
  - Counts against app's CloudKit storage

- **Private Database**: User-specific data
  - Only accessible to the owner
  - Counts against user's iCloud storage
  - Better for personal settings

For Kosudoku, use **Public Database** for multiplayer features.

### Development vs Production

1. **Development Schema**: 
   - Safe to modify freely
   - Used when running from Xcode
   - Reset anytime

2. **Production Schema**:
   - Deployed when ready for TestFlight/App Store
   - Cannot remove fields (only add)
   - Click **Deploy to Production** when ready

⚠️ **Important**: Always test thoroughly in Development before deploying to Production!

## Testing Your Setup

After creating the schema, test with this checklist:

### 1. Authentication Test
```swift
let service = CloudKitService.shared
try await service.requestPermissions()
try await service.authenticateUser()
print(service.currentUserRecordName) // Should print user ID
```

### 2. Create User Profile Test
```swift
let profile = UserProfile(
    username: "testuser",
    displayName: "Test User"
)
try await service.saveUserProfile(profile)
```

### 3. Search Test
```swift
let results = try await service.searchUsers(username: "test")
print("Found \(results.count) users")
```

### 4. Create Game Test
```swift
let (puzzle, solution) = SudokuGenerator.generatePuzzle(difficulty: .easy)
let session = GameSession(
    hostRecordName: service.currentUserRecordName!,
    difficulty: .easy,
    puzzleData: puzzle.toJSONString(),
    solutionData: solution.toJSONString()
)
try await service.createGameSession(session)
```

## Subscriptions Setup

For real-time updates, set up CloudKit subscriptions:

### In CloudKit Dashboard

1. Go to **Subscriptions**
2. Create subscription for **PlayerGameState** changes
3. Set to trigger on: Create, Update
4. Enable push notifications

### In Code

The `CloudKitService` already includes subscription code:
```swift
try await cloudKit.subscribeToGameUpdates(gameRecordName: gameRecordName)
```

## Security Rules

Consider adding security rules in CloudKit Dashboard:

1. **UserProfile**: Users can only modify their own profile
2. **GameSession**: Only host can modify game settings
3. **PlayerGameState**: Users can only modify their own state
4. **ChatMessage**: Anyone can create, no one can delete others'

## Common Issues

### "Account Not Available"
- User not signed into iCloud
- Check: Settings → [Your Name] → iCloud

### "Permission Denied"
- CloudKit capability not enabled
- Check project capabilities

### "Unknown Record Type"
- Schema not created in CloudKit Dashboard
- Or using wrong container

### "Network Unavailable"
- No internet connection
- CloudKit servers temporarily down

## Monitoring & Analytics

Use CloudKit Dashboard to monitor:
- **Usage**: API calls, storage, data transfer
- **Logs**: Real-time operation logs
- **Telemetry**: Performance metrics

## Production Checklist

Before releasing:
- [ ] Test with multiple accounts
- [ ] Test on cellular and WiFi
- [ ] Test offline behavior
- [ ] Verify data syncs correctly
- [ ] Check storage quotas
- [ ] Set up proper error handling
- [ ] Add user feedback for errors
- [ ] Test CloudKit notifications
- [ ] Deploy schema to production
- [ ] Test with production schema

## Resources

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
- [WWDC CloudKit Sessions](https://developer.apple.com/videos/cloudkit)

## Need Help?

Common troubleshooting:
1. Check Xcode console for detailed errors
2. Verify iCloud is enabled on device/simulator
3. Check CloudKit Dashboard logs
4. Ensure correct container is selected
5. Try resetting Development Environment

---

Once your schema is set up, you're ready to build and test Kosudoku! 🎮
