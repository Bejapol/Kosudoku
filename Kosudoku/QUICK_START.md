# Quick Start Guide - Kosudoku Development

Get up and running with Kosudoku in just a few minutes!

## Prerequisites

- macOS Ventura or later
- Xcode 15.0 or later
- Apple Developer account (free or paid)
- iOS 17.0+ device or simulator

## Step-by-Step Setup

### 1. Project Configuration (2 minutes)

```bash
# Open the project in Xcode
open Kosudoku.xcodeproj
```

#### A. Update Bundle Identifier
1. Select project in Navigator
2. Select **Kosudoku** target
3. **General** tab → Change **Bundle Identifier** to something unique:
   - Example: `com.yourname.Kosudoku`

#### B. Select Your Team
1. Still in **General** tab
2. **Signing & Capabilities** section
3. **Team**: Select your Apple Developer account

### 2. Enable CloudKit (3 minutes)

1. Go to **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add **iCloud**
4. Check **CloudKit**
5. Container will auto-generate as `iCloud.com.yourname.Kosudoku`

6. Click **+ Capability** again
7. Add **Background Modes**
8. Check:
   - ✅ Remote notifications
   - ✅ Background fetch

9. Click **+ Capability** once more
10. Add **Push Notifications**

### 3. CloudKit Schema Setup (5 minutes)

1. Open [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. Select your container (e.g., `iCloud.com.yourname.Kosudoku`)
3. Go to **Schema** → **Development** → **Public Database**

**Quick Schema Creation:**

For each record type below, click **New Type** and add fields:

#### UserProfile
```
username         String    [Queryable Index]
displayName      String    
totalScore       Int64     
gamesPlayed      Int64     
gamesWon         Int64     
```

#### GameSession
```
hostRecordName   String
difficulty       String
puzzleData       String
solutionData     String
status           String    [Queryable Index]
createdAt        Date/Time
startedAt        Date/Time
completedAt      Date/Time
```

#### PlayerGameState
```
playerRecordName   String
playerUsername     String
gameSession        Reference(GameSession)
currentBoardData   String
score              Int64
correctGuesses     Int64
incorrectGuesses   Int64
cellsCompleted     String(List)
joinedAt           Date/Time
lastMoveAt         Date/Time
```

#### ChatMessage
```
senderRecordName String
senderUsername   String
content          String
messageType      String
timestamp        Date/Time  [Sortable Index]
gameSession      Reference(GameSession)
groupChatID      String
```

#### Friendship
```
userRecordName     String  [Queryable Index]
friendRecordName   String  [Queryable Index]
friendUsername     String
friendDisplayName  String
status             String
createdAt          Date/Time
acceptedAt         Date/Time
```

#### GroupChat
```
name               String
creatorRecordName  String
memberRecordNames  String(List)
createdAt          Date/Time
```

📝 **Tip**: See `CLOUDKIT_SETUP.md` for detailed field configuration

### 4. Build & Run (1 minute)

1. Select a simulator or device with iOS 17+
2. Press **⌘R** or click **Run** button
3. App should build and launch

⚠️ **First Run**: You'll need to sign into iCloud in Settings (Simulator) or on device

### 5. Test the App (2 minutes)

#### Initial Setup
1. App launches → Prompted to create profile
2. Enter username and display name
3. Tap **Create**

#### Test Features
✅ **Home Tab**: 
- Tap "Start New Game"
- Select difficulty
- Game should load with Sudoku grid

✅ **Game Play**:
- Tap a cell
- Tap a number to fill
- Toggle "Notes Mode" for pencil marks

✅ **Friends Tab**:
- Tap + to add friends
- Search won't find anyone yet (need multiple accounts)

✅ **Profile Tab**:
- View your stats
- Edit profile

## Testing Multiplayer (Advanced)

To test multiplayer features, you need multiple iCloud accounts:

### Option 1: Multiple Devices
1. Sign into different iCloud accounts on different devices
2. Build and run on both
3. Create profiles on both
4. Add each other as friends
5. Create a game and invite

### Option 2: Simulator + Device
1. Use one iCloud account on device
2. Different account on simulator
3. Follow same steps as Option 1

### Testing Checklist
- [ ] Create user profile
- [ ] Start a game
- [ ] Make moves on Sudoku grid
- [ ] Test correct/incorrect answers
- [ ] Check score updates
- [ ] Test notes mode
- [ ] Create a chat (need friends)
- [ ] Send messages in game chat

## Common First-Run Issues

### "iCloud Account Not Available"
**Fix**: 
- Simulator: Settings → Sign in with Apple ID
- Device: Settings → [Your Name] → iCloud → Enable

### "CloudKit Permission Denied"
**Fix**:
- Xcode: Clean Build Folder (⇧⌘K)
- Verify iCloud capability is enabled
- Check bundle ID matches CloudKit container

### "Record Type Not Found"
**Fix**:
- Verify schema created in CloudKit Dashboard
- Make sure you're in **Development** environment
- Wait 1-2 minutes for schema propagation

### Build Errors
**Fix**:
```bash
# Clean and rebuild
⌘K (Clean)
⌘B (Build)
```

If still failing:
- Check Swift version (6.0+)
- Verify deployment target (iOS 17+)
- Update Xcode to latest version

## File Structure Overview

```
Kosudoku/
├── 📱 App Layer
│   ├── KosudokuApp.swift       # App entry, CloudKit init
│   └── ContentView.swift        # Main tab navigation
│
├── 📊 Data Models
│   ├── UserProfile.swift
│   ├── GameSession.swift
│   ├── PlayerGameState.swift
│   ├── ChatMessage.swift
│   ├── Friendship.swift
│   └── GroupChat.swift
│
├── 🎮 Game Logic
│   ├── SudokuBoard.swift        # Board structure
│   ├── SudokuGenerator.swift   # Puzzle generation
│   └── ScoringSystem.swift     # Point calculations
│
├── 🔧 Services
│   ├── CloudKitService.swift   # CloudKit operations
│   └── GameManager.swift       # Game coordination
│
└── 🎨 Views
    ├── HomeView.swift           # Main menu
    ├── GameView.swift           # Active game
    ├── SudokuGridView.swift    # 9x9 grid
    ├── FriendsView.swift       # Friend list
    ├── ChatsView.swift         # Chat list
    ├── ProfileView.swift       # User profile
    └── [11 more views...]
```

## Next Development Steps

1. **Test Core Features** ✅
   - Profile creation
   - Game creation
   - Move validation
   - Scoring

2. **Add Real-Time Sync** 🔄
   - Implement `GameManager.syncGameState()`
   - Add CloudKit subscriptions
   - Handle concurrent moves

3. **Enhance UI** 🎨
   - Add animations
   - Improve grid styling
   - Add haptic feedback
   - Sound effects

4. **Multiplayer Testing** 👥
   - Test with multiple accounts
   - Verify game state sync
   - Test chat functionality

5. **Polish & Debug** ✨
   - Error handling
   - Loading states
   - Offline support
   - Performance optimization

## Development Tips

### Quick Testing Commands

```swift
// Test CloudKit connection
Task {
    let service = CloudKitService.shared
    try await service.authenticateUser()
    print("✅ Connected:", service.currentUserRecordName ?? "nil")
}

// Test puzzle generation
let (puzzle, solution) = SudokuGenerator.generatePuzzle(difficulty: .easy)
print("✅ Puzzle generated with \(puzzle.cells.flatMap { $0 }.filter { $0.value != nil }.count) filled cells")

// Test scoring
let points = ScoringSystem.pointsForCorrectGuess(difficulty: .hard)
print("✅ Hard difficulty correct guess:", points, "points")
```

### Debugging CloudKit

Enable CloudKit logging:
```bash
# In Xcode scheme, add environment variable:
# Name: CK_LOGGING_LEVEL
# Value: 2
```

View logs:
- Xcode Console
- CloudKit Dashboard → Logs

### Reset Development Data

```bash
# CloudKit Dashboard → Schema → Development
# Click: Reset Development Environment
# Warning: Deletes all development data!
```

## Getting Help

- 📖 **README.md**: Full documentation
- ☁️ **CLOUDKIT_SETUP.md**: Detailed CloudKit guide
- 🐛 **Issues**: Check Xcode console for errors
- 💬 **Apple Forums**: [developer.apple.com/forums](https://developer.apple.com/forums/)

## Success! 🎉

You should now have:
- ✅ Project configured and building
- ✅ CloudKit enabled and schema created
- ✅ App running on simulator or device
- ✅ Able to create profile and play games

**Ready to code?** Start with implementing real-time sync in `GameManager.swift`!

---

Happy coding! 🚀
