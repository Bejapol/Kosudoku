# Kosudoku - Multiplayer Sudoku Game

A multiplayer Sudoku game built with SwiftUI, SwiftData, and CloudKit that allows players to compete in real-time races to fill Sudoku grids.

## Features

### Core Gameplay
- **Traditional Sudoku**: Classic 9x9 Sudoku grid with standard rules
- **Multiplayer Racing**: Compete with friends to fill cells first
- **Real-Time Scoring**: See all players' scores update live after every move (syncs every 5 seconds)
- **Live Leaderboard**: Expandable in-game leaderboard showing current rankings
- **Smart Scoring System**: 
  - Points for correct guesses (scaled by difficulty)
  - Penalties for incorrect guesses (scaled by difficulty)
- **Multiple Difficulty Levels**: Easy, Medium, Hard, Expert
- **Notes Mode**: Add pencil marks to cells for planning

### Social Features
- **User Profiles**: Create and customize your player profile
- **Friend System**: Add friends, send and accept friend requests
- **Group Chats**: Create group chats with friends
- **In-Game Chat**: Chat with other players during games
- **Leaderboards**: Track your stats and wins

### Cloud Integration
- **CloudKit Sync**: Real-time game state synchronization
- **iCloud Authentication**: Seamless login with iCloud account
- **Cross-Device Play**: Start on one device, continue on another

## Architecture

### Data Models

#### Core Models (`/Models`)
- **UserProfile**: User account and statistics
- **GameSession**: Represents a multiplayer game
- **PlayerGameState**: Individual player's state in a game
- **ChatMessage**: Chat messages for games and groups
- **Friendship**: Friend connections between users
- **GroupChat**: Group chat rooms

### Game Logic (`/Game`)
- **SudokuBoard**: Board data structure with cells
- **SudokuGenerator**: Generates valid Sudoku puzzles
- **ScoringSystem**: Calculates points and bonuses

### Services (`/Services`)
- **CloudKitService**: Handles all CloudKit operations
- **GameManager**: Coordinates game state and multiplayer sync

### Views (`/Views`)
- **ContentView**: Main tab-based navigation
- **HomeView**: Game list and quick play
- **GameView**: Active game interface with Sudoku grid
- **SudokuGridView**: Interactive 9x9 grid component
- **FriendsView**: Friend list and management
- **ChatsView**: Group chat list
- **ProfileView**: User profile and statistics

## Setup Instructions

### 1. Xcode Project Configuration

#### Enable CloudKit
1. Open your project in Xcode
2. Select your target → **Signing & Capabilities**
3. Click **+ Capability** → Add **iCloud**
4. Check **CloudKit**
5. Create a new CloudKit container or use the default

#### Add Push Notifications (for real-time updates)
1. In **Signing & Capabilities**
2. Click **+ Capability** → Add **Push Notifications**
3. Add **Background Modes**
4. Check **Remote notifications**

#### Update Info.plist
Add the following keys if needed:
```xml
<key>NSUserTrackingUsageDescription</key>
<string>We use this to sync your game progress across devices</string>
```

### 2. CloudKit Dashboard Setup

1. Open [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. Select your container
3. Create the following **Record Types** in the Public Database:

#### UserProfile
- `username` (String, Indexed, Queryable)
- `displayName` (String, Queryable)
- `totalScore` (Int64)
- `gamesPlayed` (Int64)
- `gamesWon` (Int64)
- `avatar` (Asset)

#### GameSession
- `hostRecordName` (String)
- `difficulty` (String)
- `puzzleData` (String)
- `solutionData` (String)
- `status` (String, Indexed, Queryable)
- `createdAt` (Date/Time)
- `startedAt` (Date/Time)
- `completedAt` (Date/Time)

#### PlayerGameState
- `playerRecordName` (String)
- `playerUsername` (String)
- `currentBoardData` (String)
- `score` (Int64)
- `correctGuesses` (Int64)
- `incorrectGuesses` (Int64)
- `cellsCompleted` (List<String>)
- `joinedAt` (Date/Time)
- `lastMoveAt` (Date/Time)
- `gameSession` (Reference to GameSession)

#### ChatMessage
- `senderRecordName` (String)
- `senderUsername` (String)
- `content` (String)
- `messageType` (String)
- `timestamp` (Date/Time, Indexed)
- `gameSession` (Reference to GameSession)
- `groupChatID` (String, Indexed)

#### Friendship
- `userRecordName` (String, Indexed, Queryable)
- `friendRecordName` (String, Indexed, Queryable)
- `friendUsername` (String)
- `friendDisplayName` (String)
- `status` (String)
- `createdAt` (Date/Time)
- `acceptedAt` (Date/Time)

#### GroupChat
- `name` (String)
- `creatorRecordName` (String)
- `memberRecordNames` (List<String>)
- `createdAt` (Date/Time)

### 3. Build and Run

1. Build the project (⌘B)
2. Fix any import or compilation errors
3. Run on simulator or device (⌘R)
4. Sign in with an iCloud account when prompted

## Next Steps & Enhancements

### Essential Features to Complete

1. **Real-time Sync Enhancement**
   - Implement periodic fetching of player states
   - Add CloudKit subscriptions for push notifications
   - Update `GameManager.syncGameState()` method

2. **Game Invitations**
   - Send notifications to invited players
   - Create lobby/waiting room UI
   - Handle game start countdown

3. **Enhanced Chat**
   - Real-time message sync
   - Typing indicators
   - Read receipts

4. **Leaderboards**
   - Global leaderboard view
   - Friend leaderboards
   - Weekly/monthly rankings

5. **Game History**
   - Detailed game replay
   - Statistics per game
   - Share results

### Optional Enhancements

- **Achievements System**: Track milestones and award badges
- **Daily Challenges**: New puzzle each day
- **Tournaments**: Organized competitive events
- **Power-ups**: Special abilities (hints, auto-fill, etc.)
- **Themes**: Customizable grid colors and styles
- **Sound Effects**: Audio feedback for moves
- **Animations**: Smooth transitions and effects
- **iPad Optimization**: Better use of larger screens
- **Mac Catalyst**: Support for macOS

## Code Structure

```
Kosudoku/
├── KosudokuApp.swift          # App entry point
├── ContentView.swift           # Main tab view
├── Models/
│   ├── UserProfile.swift
│   ├── GameSession.swift
│   ├── PlayerGameState.swift
│   ├── ChatMessage.swift
│   ├── Friendship.swift
│   └── GroupChat.swift
├── Game/
│   ├── SudokuBoard.swift
│   ├── SudokuGenerator.swift
│   └── ScoringSystem.swift
├── Services/
│   ├── CloudKitService.swift
│   └── GameManager.swift
└── Views/
    ├── HomeView.swift
    ├── GameView.swift
    ├── SudokuGridView.swift
    ├── NewGameView.swift
    ├── FriendsView.swift
    ├── AddFriendView.swift
    ├── ChatsView.swift
    ├── GroupChatView.swift
    ├── GameChatView.swift
    ├── NewChatView.swift
    ├── ProfileView.swift
    ├── EditProfileView.swift
    └── ProfileSetupView.swift
```

## Scoring System Details

### Base Points
- **Correct Guess**: 10 points × difficulty multiplier
- **Incorrect Guess**: -5 points

### Difficulty Multipliers
- **Easy**: 1.0×
- **Medium**: 1.5×
- **Hard**: 2.0×
- **Expert**: 2.5×

### Score
- **Final Score**: Sum of correct-guess points minus incorrect-guess penalties (minimum 0)

## Testing

### Test CloudKit Functionality
1. Test with multiple iCloud accounts
2. Verify data sync across devices
3. Test offline behavior and sync on reconnect

### Test Game Logic
1. Verify puzzle generation creates valid boards
2. Test move validation
3. Confirm scoring calculations
4. Test multiplayer cell claiming

## Known Limitations

1. **Sudoku Generation**: Current algorithm is basic. Consider implementing more sophisticated generation for guaranteed unique solutions.
2. **Real-time Sync**: Currently uses timer-based polling. WebSocket or more frequent CloudKit queries recommended.
3. **Conflict Resolution**: If two players submit the same cell simultaneously, last-write-wins. Consider implementing more sophisticated conflict resolution.
4. **Offline Mode**: Limited offline support. Consider caching and sync queue.

## Contributing

Feel free to enhance and expand this project! Key areas for contribution:
- Improved puzzle generation algorithms
- Better UI/UX design
- Performance optimizations
- Additional game modes

## License

This project is provided as-is for educational purposes.

---

Built with ❤️ using Swift, SwiftUI, SwiftData, and CloudKit
