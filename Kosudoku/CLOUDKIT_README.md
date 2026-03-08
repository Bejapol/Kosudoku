# CloudKit Schema Files

This directory contains everything you need to set up your CloudKit database.

## Files

### 📦 Schema Import (Easiest!)

**[cloudkit-schema.json](cloudkit-schema.json)** - Complete schema in JSON format
- Import this file directly using CloudKit Console tools
- Creates all 6 record types with 43 fields and 10 indexes automatically
- See [CLOUDKIT_IMPORT_GUIDE.md](CLOUDKIT_IMPORT_GUIDE.md) for instructions

### 📖 Setup Guides

Choose the method that works best for you:

1. **[CLOUDKIT_IMPORT_GUIDE.md](CLOUDKIT_IMPORT_GUIDE.md)** ⭐ **EASIEST**
   - Import schema with one command
   - Uses CloudKit Console tools (`cktool`)
   - Takes 30 seconds

2. **[CLOUDKIT_VISUAL_GUIDE.md](CLOUDKIT_VISUAL_GUIDE.md)** 
   - Step-by-step visual walkthrough
   - Manual creation via web dashboard
   - Takes 10-15 minutes

3. **[CLOUDKIT_DASHBOARD_GUIDE.md](CLOUDKIT_DASHBOARD_GUIDE.md)**
   - Detailed troubleshooting guide
   - Covers different dashboard versions
   - Reference when stuck

4. **[CLOUDKIT_CHECKLIST.md](CLOUDKIT_CHECKLIST.md)**
   - Printable checklist
   - Track your progress
   - Verify completion

5. **[CLOUDKIT_SETUP.md](CLOUDKIT_SETUP.md)**
   - Original comprehensive guide
   - Links to all other resources
   - Testing and security info

## Quick Start

### Method 1: Command Line Import (30 seconds)

```bash
# Navigate to project directory
cd /path/to/Kosudoku

# Import schema (replace with your container name)
xcrun cktool import-schema cloudkit-schema.json \
  --container iCloud.com.yourname.Kosudoku \
  --environment development

# Done! ✅
```

See [CLOUDKIT_IMPORT_GUIDE.md](CLOUDKIT_IMPORT_GUIDE.md) for detailed instructions.

### Method 2: Manual Creation (10-15 minutes)

1. Open [CLOUDKIT_VISUAL_GUIDE.md](CLOUDKIT_VISUAL_GUIDE.md)
2. Follow the step-by-step instructions
3. Check off items in [CLOUDKIT_CHECKLIST.md](CLOUDKIT_CHECKLIST.md)

## What Gets Created

The schema includes **6 record types** for your multiplayer Sudoku game:

| Record Type | Purpose | Fields | Indexes |
|-------------|---------|--------|---------|
| **UserProfile** | Player accounts and stats | 7 | 2 |
| **GameSession** | Active and completed games | 8 | 2 |
| **PlayerGameState** | Player's state in a game | 10 | 1 |
| **ChatMessage** | In-game and group chat | 7 | 2 |
| **Friendship** | Friend connections | 7 | 3 |
| **GroupChat** | Group chat rooms | 4 | 0 |
| **TOTAL** | | **43** | **10** |

## Verification

After setup, verify your schema:

### Via Dashboard
1. Go to [icloud.developer.apple.com/dashboard](https://icloud.developer.apple.com/dashboard/)
2. Select your container
3. Schema → Development → Public Database
4. Should see all 6 record types

### Via Swift Code
```swift
import CloudKit

Task {
    let database = CKContainer.default().publicCloudDatabase
    let query = CKQuery(recordType: "UserProfile", predicate: NSPredicate(value: false))
    try await database.records(matching: query, desiredKeys: nil, resultsLimit: 1)
    print("✅ Schema is working!")
}
```

### Via Command Line
```bash
xcrun cktool list-record-types \
  --container iCloud.com.yourname.Kosudoku \
  --environment development
```

Should output:
```
UserProfile
GameSession
PlayerGameState
ChatMessage
Friendship
GroupChat
```

## Troubleshooting

### Can't Import Schema?
- Check [CLOUDKIT_IMPORT_GUIDE.md](CLOUDKIT_IMPORT_GUIDE.md) troubleshooting section
- Or use manual method: [CLOUDKIT_VISUAL_GUIDE.md](CLOUDKIT_VISUAL_GUIDE.md)

### Dashboard Interface Confusing?
- Try [CLOUDKIT_DASHBOARD_GUIDE.md](CLOUDKIT_DASHBOARD_GUIDE.md)
- Shows different UI variations

### Lost Track of Progress?
- Use [CLOUDKIT_CHECKLIST.md](CLOUDKIT_CHECKLIST.md)
- Check off completed items

## Need Help?

1. **First**: Try the import method (fastest!)
2. **If stuck**: Check troubleshooting sections in guides
3. **Still stuck**: Use visual guide for manual creation
4. **Reference**: Use JSON schema file as your source of truth

## File Purpose Summary

| File | Use When |
|------|----------|
| `cloudkit-schema.json` | You want to import automatically |
| `CLOUDKIT_IMPORT_GUIDE.md` | You're using command line tools |
| `CLOUDKIT_VISUAL_GUIDE.md` | You're creating manually and want simple steps |
| `CLOUDKIT_DASHBOARD_GUIDE.md` | You're stuck and need troubleshooting |
| `CLOUDKIT_CHECKLIST.md` | You want to track your manual progress |
| `CLOUDKIT_SETUP.md` | You want comprehensive overview |

---

**Choose your path and get started! The schema setup is the same either way.** 🚀
