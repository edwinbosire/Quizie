# Progress Analytics UI Preview

## Main Handbook Screen

### Before (No Progress)
```
┌─────────────────────────────────────┐
│  OFFICIAL STUDY GUIDE               │
│  Life in the                        │
│  United Kingdom                     │
│  Your complete guide to British...  │
│  ═══════════════                    │
└─────────────────────────────────────┘

CHAPTERS

┌─────────────────────────────────────┐
│ CHAPTER 1                           │
│ The Values and Principles           │
│ of the UK                           │
│ [Democracy] [Rule of Law]           │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ CHAPTER 2                           │
│ What is the UK?                     │
│ [History] [Geography]               │
└─────────────────────────────────────┘
```

### After (With Progress)
```
┌─────────────────────────────────────┐
│  OFFICIAL STUDY GUIDE               │
│  Life in the                        │
│  United Kingdom                     │
│  Your complete guide to British...  │
│  ═══════════════                    │
└─────────────────────────────────────┘

CHAPTERS

┌─────────────────────────────────────┐
│ 📈 Your Progress                    │
│                                     │
│ Overall Completion          42%     │
│ ████████████░░░░░░░░░░░░░░          │
│                                     │
│ ┌──────────────┬──────────────┐    │
│ │ 🕐           │ 📖           │    │
│ │ Reading Time │ Last Read    │    │
│ │ 2h 34m       │ Today 3:45PM │    │
│ └──────────────┴──────────────┘    │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ CHAPTER 1                 ✓ Complete│
│ The Values and Principles           │
│ of the UK                           │
│ [Democracy] [Rule of Law]    🕐 45m │
│ ████████████████████████████████    │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ CHAPTER 2                  23% Read │
│ What is the UK?                     │
│ [History] [Geography]       🕐 1h 2m│
│ ███████░░░░░░░░░░░░░░░░░░░░░        │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ CHAPTER 3                           │
│ A Long and Illustrious History      │
│ [History] [Monarchy]        🕐 47m  │
└─────────────────────────────────────┘
```

## Progress Analytics Card - Detailed View

```
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║  📈 Your Progress                                         ║
║                                                           ║
║  Overall Completion                               42%     ║
║  ╔═══════════════════════════════════════════════════╗   ║
║  ║████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░║   ║
║  ╚═══════════════════════════════════════════════════╝   ║
║                                                           ║
║  ┌─────────────────────────┬─────────────────────────┐   ║
║  │                         │                         │   ║
║  │  ◉  Reading Time        │  ◉  Last Read          │   ║
║  │  🕐                     │  📖                     │   ║
║  │  Reading Time           │  Last Read              │   ║
║  │  2h 34m                 │  Today at 3:45 PM       │   ║
║  │                         │                         │   ║
║  └─────────────────────────┴─────────────────────────┘   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

## Individual Chapter Card with Reading Time

```
╔═══════════════════════════════════════════════════════════╗
║┃                                                          ║
║┃ CHAPTER 2                                     23% Read   ║
║┃                                                          ║
║┃ What is the UK?                                          ║
║┃                                                          ║
║┃ [History] [Geography] [Culture]              🕐 1h 2m   ║
║┃                                                          ║
║┃ ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░           ║
╚═══════════════════════════════════════════════════════════╝
 ▲
 └── Colored accent bar (chapter-specific color)
```

## Date Formatting Examples

The "Last Read" field intelligently formats dates:

| Actual Date/Time          | Display              |
|---------------------------|----------------------|
| Today, 3:45 PM            | Today at 3:45 PM     |
| Yesterday, any time       | Yesterday            |
| Monday (this week)        | Monday               |
| Tuesday (this week)       | Tuesday              |
| January 15, 2026          | 1/15/26              |
| Two weeks ago             | 3/14/26              |

## Reading Time Formatting Examples

| Total Seconds | Display    |
|---------------|------------|
| 120           | 2 min      |
| 2700          | 45 min     |
| 3660          | 1h 1m      |
| 9000          | 2h 30m     |
| 10800         | 3 hours    |
| 12600         | 3h 30m     |

## Progress Badges

```
Chapter not started:
┌────────────────┐
│ CHAPTER 1      │  (no badge)
└────────────────┘

Chapter in progress:
┌────────────────────┐
│ CHAPTER 1    23%   │  (percentage badge)
└────────────────────┘

Chapter completed:
┌─────────────────────────┐
│ CHAPTER 1  ✓ Completed  │  (green checkmark badge)
└─────────────────────────┘
```

## Color Scheme

### Progress Analytics Card
- **Border**: Accent color with 20% opacity (`Color.hbAccent.opacity(0.2)`)
- **Background**: Surface color (`Color.hbSurface`)
- **Progress Bar Track**: Surface2 (`Color.hbSurface2`)
- **Progress Bar Fill**: Gradient from accent to accent 70% opacity
- **Icons**: Accent color in 12% opacity circles
- **Text Primary**: `Color.hbTextPrimary`
- **Text Secondary**: `Color.hbTextSecondary`
- **Text Muted**: `Color.hbTextMuted`

### Stat Boxes
- **Background**: Surface2 with 50% opacity (`Color.hbSurface2.opacity(0.5)`)
- **Icon Circle**: Accent color with 12% opacity
- **Icon**: Accent color
- **Border Radius**: Small radius (`HBRadius.sm`)

## Interaction Flow

### 1. User Opens App
```
HandbookView loads
  ↓
@Query fetches all ReadingProgress records
  ↓
If allProgress.isEmpty → No analytics card shown
  ↓
If allProgress has data → Analytics card appears
```

### 2. User Opens Chapter
```
ChapterView appears
  ↓
onAppear triggered
  ↓
ReadingProgress.getOrCreate(for: chapterId)
  ↓
progress.startReadingSession()
  ↓
sessionStartTime = Date()
```

### 3. User Reads Chapter
```
User scrolls through content
  ↓
onScrollGeometryChange updates scrollOffset
  ↓
updateReadingProgress() called
  ↓
progress.updateProgress(...) updates percentage
  ↓
lastReadDate updated to now
```

### 4. User Leaves Chapter
```
ChapterView disappears
  ↓
onDisappear triggered
  ↓
progress.endReadingSession()
  ↓
sessionDuration = now - sessionStartTime
  ↓
If sessionDuration > 2 seconds:
    totalReadingTime += sessionDuration
  ↓
sessionStartTime = nil
  ↓
modelContext.save()
```

### 5. User Returns to Handbook
```
HandbookView loads
  ↓
ChapterList queries all progress
  ↓
Analytics card shows updated stats:
  - New overall completion %
  - Increased total reading time
  - Updated "Last Read" date
```

## Edge Cases Handled

### No Progress Data
- Analytics card hidden
- Chapter cards show no progress indicators
- No reading time displayed

### Very Short Sessions (< 2 seconds)
- Not counted in total reading time
- Prevents accidental taps from inflating time

### Multiple Sessions
- Time accumulates across all sessions
- Each session tracked independently
- Total time is sum of all sessions

### Date Edge Cases
- Today but after midnight: Shows "Today at [time]"
- Exactly 24 hours ago: Shows "Yesterday"
- Week boundary: Switches from day name to date

### Time Edge Cases
- 0 seconds: Not displayed
- 1 minute: "1 min"
- Exactly 1 hour: "1 hour"
- Very long sessions: Properly formatted (e.g., "12h 45m")

## Accessibility Features

All components use:
- ✅ Semantic colors from design system
- ✅ Proper contrast ratios
- ✅ SF Symbols for icons (VoiceOver compatible)
- ✅ Readable font sizes (11pt minimum)
- ✅ Scalable text with system fonts
- ✅ Clear visual hierarchy

## Performance Considerations

### Efficient Queries
- SwiftData predicates for filtering
- Lazy loading with @Query
- Minimal fetch descriptors

### Computed Properties
- Only computed when needed
- Cached by SwiftUI view system
- No redundant calculations

### Memory Management
- SwiftData handles object lifecycle
- No retain cycles
- Proper use of weak/unowned where needed

## Testing Scenarios

### Scenario 1: New User
1. Install app
2. Open HandbookView
3. ✅ No analytics card should appear
4. Open Chapter 1
5. Read for 5 minutes
6. Return to handbook
7. ✅ Analytics card appears with 5min reading time

### Scenario 2: Returning User
1. User has 3 chapters partially read
2. Open HandbookView
3. ✅ Analytics shows ~60% completion
4. ✅ Shows accumulated reading time
5. ✅ Shows last chapter read date

### Scenario 3: Quick Navigation
1. Tap chapter card
2. Immediately tap back
3. ✅ Session < 2 seconds not counted
4. Reading time unchanged

### Scenario 4: Long Session
1. Read chapter for 30 minutes
2. Leave app (background)
3. Return to app
4. ✅ 30 minutes added to total time
5. ✅ Chapter shows progress

### Scenario 5: Complete All Chapters
1. Read all 5 chapters to 100%
2. ✅ Overall completion shows 100%
3. ✅ All chapters show ✓ Completed badge
4. ✅ Total time reflects all reading sessions
