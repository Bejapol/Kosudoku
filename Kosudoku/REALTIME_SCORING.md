# Real-Time Scoring System Documentation

## Overview

Kosudoku features a **fully real-time scoring system** where all players can see scores update immediately after each move, not just at the end of the game.

## How It Works

### 1. **Instant Score Updates** ⚡

Every time a player makes a move:

```swift
// In GameManager.makeMove()
if isCorrect {
    // Points calculated IMMEDIATELY
    let points = ScoringSystem.pointsForCorrectGuess(difficulty: game.difficulty)
    playerState.score += points
    playerState.correctGuesses += 1
} else {
    // Penalty applied IMMEDIATELY
    playerState.score += ScoringSystem.pointsForIncorrectGuess() // -5 points
    playerState.incorrectGuesses += 1
}

// Synced to CloudKit RIGHT AWAY
try await cloudKit.savePlayerState(playerState, gameRecordName: gameRecordName)
```

**Result**: Your score updates instantly, visible on your screen immediately.

### 2. **Live Leaderboard** 🏆

The `LiveLeaderboardView` shows all players' current scores:

#### Compact Mode (Default)
Shows top 3 players with:
- Position badge (🥇 🥈 🥉)
- Player username
- Current score
- Correct/incorrect count

#### Expanded Mode (Tap to expand)
Shows ALL players with:
- Full leaderboard ranking
- Detailed stats per player
- Cells completed count
- Real-time position updates

```swift
LiveLeaderboardView(
    currentPlayer: gameManager.currentPlayerState,
    otherPlayers: gameManager.otherPlayers
)
```

### 3. **Auto-Sync Every 5 Seconds** 🔄

The `GameManager` automatically fetches other players' scores:

```swift
// Starts when game begins
private func startSyncTimer() {
    syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        Task {
            await self?.syncGameState()
        }
    }
}
```

**What gets synced:**
- ✅ All players' current scores
- ✅ Correct/incorrect guess counts
- ✅ Cells completed by each player
- ✅ Latest board state with all moves
- ✅ Position rankings

### 4. **Smart Board Merging** 🧩

When syncing, the game merges boards intelligently:

```swift
// If another player filled a cell, show it on your board
if updatedCell.value != nil && currentCell.value == nil {
    currentBoardState[row, col] = updatedCell
}

// Track who completed each cell
if let completedBy = updatedCell.completedBy {
    currentBoardState[row, col].completedBy = completedBy
}
```

**This means:**
- You see moves from other players appear on your grid
- Color coding shows who completed which cells
- No duplicate work - can't fill a cell someone else already did

## Live Score Updates Flow

```
Player Makes Move
       ↓
Score Calculated Instantly
       ↓
Saved to CloudKit (< 1 second)
       ↓
Other Players' Devices Fetch Update (every 5 seconds)
       ↓
Leaderboard Updates Automatically
       ↓
All Players See New Rankings
```

## Score Calculation Details

### Per-Move Scoring

**Correct Answer:**
```swift
Base Points = 10
Difficulty Multiplier:
  - Easy:   1.0x = 10 points
  - Medium: 1.5x = 15 points
  - Hard:   2.0x = 20 points
  - Expert: 2.5x = 25 points
```

**Incorrect Answer:**
```swift
Penalty = -5 points (no multiplier)
```

### Continuous Score Display

Players always see:
- ✅ **Their current score** - Updates instantly after each move
- ✅ **Their correct/incorrect count** - Live counter
- ✅ **Other players' scores** - Updates every 5 seconds
- ✅ **Current ranking** - 1st, 2nd, 3rd, etc.
- ✅ **Competition status** - Who's winning, by how much

## UI Components for Real-Time Scoring

### 1. Live Leaderboard (New!)

**Location**: Top of GameView

**Features:**
- Tap to expand/collapse
- Shows all players sorted by score
- Color-coded: blue = you, others = default
- Position badges with medals
- Live stats (correct, incorrect, cells completed)

### 2. Score Header

**Shows:**
```
Score: 150          ⏱️ 05:32          👥 3 players
Medium              ✓ 15 | ✗ 2
```

### 3. Real-Time Notifications (Optional Enhancement)

You could add toast notifications for:
- "Alice completed a cell! (+15 points)"
- "You're now in 1st place! 🏆"
- "Bob is catching up!"

## Code Examples

### Accessing Live Scores

```swift
// Get current player's score
let myScore = gameManager.currentPlayerState?.score ?? 0

// Get all players sorted by score
let rankings = ([gameManager.currentPlayerState] + gameManager.otherPlayers)
    .compactMap { $0 }
    .sorted { $0.score > $1.score }

// Find your ranking
if let myPosition = rankings.firstIndex(where: { 
    $0.playerRecordName == currentUserRecordName 
}) {
    print("You're in position \(myPosition + 1)")
}
```

### Displaying Scores in Custom UI

```swift
struct CustomScoreView: View {
    @Bindable var gameManager: GameManager
    
    var body: some View {
        VStack {
            // Your score - updates immediately
            Text("Your Score: \(gameManager.currentPlayerState?.score ?? 0)")
                .font(.largeTitle)
                .bold()
            
            // Other players - updates every 5 seconds
            ForEach(gameManager.otherPlayers, id: \.id) { player in
                HStack {
                    Text(player.playerUsername)
                    Spacer()
                    Text("\(player.score) pts")
                }
            }
        }
    }
}
```

## Performance & Optimization

### Why 5-Second Intervals?

**Balance between:**
- ✅ **Real-time feel** - Frequent enough to feel live
- ✅ **Battery efficiency** - Not constantly polling
- ✅ **CloudKit limits** - Stays within API quotas
- ✅ **Network efficiency** - Reduces data usage

### Customizing Sync Frequency

Want faster updates? Change the interval:

```swift
// In GameManager.swift
private func startSyncTimer() {
    // Change 5.0 to 2.0 for 2-second updates
    syncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
        Task {
            await self?.syncGameState()
        }
    }
}
```

⚠️ **Warning**: Faster syncing = more API calls = higher CloudKit costs

### Push Notifications (Advanced)

For truly instant updates, implement CloudKit subscriptions:

```swift
// Already set up in CloudKitService
try await cloudKit.subscribeToGameUpdates(gameRecordName: gameRecordName)

// In AppDelegate or @main
func userNotificationCenter(_ center: UNUserNotificationCenter, 
                           didReceive response: UNNotificationResponse) {
    // Trigger immediate sync when push received
    Task {
        await gameManager.syncGameState()
    }
}
```

## Testing Real-Time Scoring

### Single Device Test

1. Start a game
2. Make correct move → Score updates instantly ✅
3. Make incorrect move → Score drops immediately ✅

### Multi-Device Test

1. **Device A**: Sign in with Account 1
2. **Device B**: Sign in with Account 2
3. **Device A**: Create and start game
4. **Device B**: Join same game
5. **Device A**: Make a move → Score updates instantly
6. **Device B**: Wait ~5 seconds → See Device A's score update ✅
7. **Device B**: Make a move → Score updates instantly
8. **Device A**: Wait ~5 seconds → See Device B's score update ✅

### Leaderboard Test

1. Start game with 3+ players
2. Have each player make moves
3. Watch leaderboard reorder in real-time
4. Tap leaderboard to expand
5. Verify all stats update correctly

## Scoring Events Timeline

```
Time    Event                           Your Score    Alice's Score
00:00   Game starts                     0             0
00:15   You: Correct (Easy)            +10            0
00:20   CloudKit synced                 10            0
00:25   Alice: Correct (Easy)           10           +10
00:30   Your device syncs               10            10  ← You see Alice's score
00:45   You: Correct (Easy)            +10            10
00:50   You: Incorrect                  -5            10
01:00   Alice sees your updates         15            10
01:15   Alice: Correct (Easy)           15           +10
01:20   Your device syncs               15            20  ← Alice is winning!
```

## Final Score Calculation

The final score is simply the running total from all moves:

```swift
Final Score = Sum of correct-guess points - Sum of incorrect-guess penalties (minimum 0)
```

## Summary

### ✅ What You Get

- **Instant feedback** on your own moves
- **Live leaderboard** updating every 5 seconds
- **Real-time competition** - see who's winning
- **Move tracking** - see cells others complete
- **Smart syncing** - efficient network usage
- **Responsive UI** - smooth, no lag

### 🎯 User Experience

Players experience a **truly multiplayer racing game** where:
1. They see their score update **instantly** after each move
2. They see competitors' scores update **every 5 seconds**
3. The leaderboard shows **live rankings**
4. The board shows **moves from all players**
5. Competition feels **real-time and engaging**

### 📊 Technical Benefits

- Efficient CloudKit usage
- Battery-friendly sync intervals
- Smooth UI updates with @Observable
- No blocking operations
- Handles offline gracefully

---

**The game is fully set up for real-time scoring!** All players can see live scores throughout the entire game, making it a truly competitive multiplayer experience. 🏆
