# Visual Before & After Comparison

## QuizLobbyView Info Cards Update

### BEFORE (Info cards always visible)

```
╔═══════════════════════════════════════════════╗
║                                               ║
║   🎯 PRACTICE TEST                           ║
║   Life in the UK Practice Exam                ║
║   Test your knowledge with a full-length...   ║
║                                               ║
╚═══════════════════════════════════════════════╝

┌───────────────────┬───────────────────┐
│                   │                   │
│    ❓ 24          │    ⏰ 45          │
│    Questions      │    Minutes        │
│                   │                   │
├───────────────────┼───────────────────┤
│                   │                   │
│    ✅ 18/24       │    🔀 ∞          │
│    Pass Mark      │    Random         │
│                   │                   │
└───────────────────┴───────────────────┘
           ↑
    Always visible (even after exams)

┌─────────────────────────────────────────────┐
│ BEFORE YOU START                            │
│ 1. Read each question carefully...          │
│ 2. Some questions require TWO...            │
│ 3. You cannot go back...                    │
│ 4. The exam ends when...                    │
└─────────────────────────────────────────────┘

╔═══════════════════════════════════════════════╗
║          ▶  Start Practice Exam              ║
╚═══════════════════════════════════════════════╝
```

---

### AFTER - First Time User (No attempts)

```
╔═══════════════════════════════════════════════╗
║                                               ║
║   🎯 PRACTICE TEST                            ║
║   Life in the UK Practice Exam                ║
║   Test your knowledge with a full-length...   ║
║                                               ║
╚═══════════════════════════════════════════════╝

┌───────────────────┬───────────────────┐
│                   │                   │
│    ❓ 24          │    ⏰ 45          │
│    Questions      │    Minutes        │
│                   │                   │
├───────────────────┼───────────────────┤
│                   │                   │
│    ✅ 18/24       │    🔀 ∞           │
│    Pass Mark      │    Random         │
│                   │                   │
└───────────────────┴───────────────────┘
           ↑
    Visible for new users ✅

┌─────────────────────────────────────────────┐
│ BEFORE YOU START                            │
│ 1. Read each question carefully...          │
│ 2. Some questions require TWO...            │
│ 3. You cannot go back...                    │
│ 4. The exam ends when...                    │
└─────────────────────────────────────────────┘

╔═══════════════════════════════════════════════╗
║          ▶  Start Practice Exam               ║
╚═══════════════════════════════════════════════╝
```

---

### AFTER - Returning User (With attempts)

```
╔═══════════════════════════════════════════════╗
║                                               ║
║   🎯 PRACTICE TEST                           ║
║   Life in the UK Practice Exam                ║
║   Test your knowledge with a full-length...   ║
║                                               ║
╚═══════════════════════════════════════════════╝

╔═══════════════════════════════════════════════╗
║ YOUR PROGRESS                      3          ║
║ Great work! Keep practicing...   ATTEMPTS     ║
║                                               ║
║  ┌───────┬───────┬───────┐                  ║
║  │ 75%   │ 22/24 │ 66%   │                  ║
║  │ Avg   │ Best  │ Pass  │                  ║
║  │ Score │ Score │ Rate  │                  ║
║  └───────┴───────┴───────┘                  ║
╚═══════════════════════════════════════════════╝
           ↑
    Replaces info cards ✨

╔═══════════════════════════════════════════════╗
║ RECENT ATTEMPTS                               ║
║ ┌───────────────────────────────────────────┐ ║
║ │ ✅ Passed      22/24      30:15  2m ago   │ ║
║ └───────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────┐ ║
║ │ ❌ Not Passed  16/24      42:10  1d ago   │ ║
║ └───────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────┐ ║
║ │ ✅ Passed      20/24      35:45  3d ago   │ ║
║ └───────────────────────────────────────────┘ ║
╚═══════════════════════════════════════════════╝
           ↑
    Shows exam history 📊

┌─────────────────────────────────────────────┐
│ BEFORE YOU START                            │
│ 1. Read each question carefully...          │
│ 2. Some questions require TWO...            │
│ 3. You cannot go back...                    │
│ 4. The exam ends when...                    │
└─────────────────────────────────────────────┘

╔═══════════════════════════════════════════════╗
║          ▶  Try Another Exam                 ║
╚═══════════════════════════════════════════════╝
```

---

## Key Differences

### Layout Changes

| Element                | Before          | After (New User) | After (Returning) |
|------------------------|-----------------|------------------|-------------------|
| Hero Section           | ✅ Visible      | ✅ Visible       | ✅ Visible        |
| **Info Cards**         | **✅ Visible**  | **✅ Visible**   | **❌ Hidden**     |
| Performance Summary    | Conditional     | ❌ Hidden        | ✅ Visible        |
| Recent Attempts        | Conditional     | ❌ Hidden        | ✅ Visible        |
| Rules Card             | ✅ Visible      | ✅ Visible       | ✅ Visible        |
| Start Button           | ✅ Visible      | ✅ Visible       | ✅ Visible        |

### Content Hierarchy

**First-Time User:**
```
1. Hero (what this is)
2. Info Cards (exam details) ← Important for new users
3. Rules (what to expect)
4. Start Button (CTA)
```

**Returning User:**
```
1. Hero (what this is)
2. Performance Summary (your stats) ← More relevant
3. Recent Attempts (your history)
4. Rules (reminder)
5. Try Again Button (CTA)
```

---

## Animation Transition

When cards disappear (after first exam completion):

```
Frame 1 (100% opacity, 100% scale)
┌───────────────────┬───────────────────┐
│    ❓ 24          │    ⏰ 45          │
│    Questions      │    Minutes        │
├───────────────────┼───────────────────┤
│    ✅ 18/24       │    🔀 ∞          │
│    Pass Mark      │    Random         │
└───────────────────┴───────────────────┘

        ↓ 0.3 seconds

Frame 2 (50% opacity, 97.5% scale)
┌─────────────────┬─────────────────┐
│   ❓ 24         │   ⏰ 45         │
│   Questions     │   Minutes       │  [Fading & shrinking]
├─────────────────┼─────────────────┤
│   ✅ 18/24      │   🔀 ∞         │
│   Pass Mark     │   Random        │
└─────────────────┴─────────────────┘

        ↓ 0.3 seconds

Frame 3 (0% opacity, 95% scale)
[Cards completely gone]

╔═══════════════════════════════════════════════╗
║ YOUR PROGRESS                      1          ║
║ Keep going! Practice makes perfect. ATTEMPTS  ║  [Slides in]
║                                               ║
║  [Performance stats appear]                   ║
╚═══════════════════════════════════════════════╝
```

---

## Screen Space Comparison

### Before (with info cards)
```
Total vertical space used:
- Hero: 200px
- Info Cards: 240px (4 cards @ 120px each in 2×2 grid)
- Rules: 180px
Total: 620px
```

### After (returning user)
```
Total vertical space used:
- Hero: 200px
- Performance Summary: 180px
- Recent Attempts: 220px (3 attempts)
- Rules: 180px
Total: 780px

More content, better use of space! ✨
```

---

## User Journey Visualization

```
New User Flow:
┌──────────┐
│   Open   │
│   Quiz   │
└────┬─────┘
     │
     ▼
┌──────────────┐
│  See Info    │  ← Cards explain exam format
│  Cards       │
└────┬─────────┘
     │
     ▼
┌──────────────┐
│ Read Rules   │
└────┬─────────┘
     │
     ▼
┌──────────────┐
│ Start Exam   │
└────┬─────────┘
     │
     ▼
┌──────────────┐
│ Complete     │
│ Exam         │
└────┬─────────┘
     │
     ▼
┌──────────────┐
│ Return to    │  ← Now sees Performance Summary
│ Lobby        │    instead of Info Cards
└──────────────┘
```

---

## Responsive Behavior

### Portrait Mode (iPhone)
```
Cards in 2×2 grid:
┌──────┬──────┐
│  24  │  45  │
├──────┼──────┤
│18/24 │  ∞   │
└──────┴──────┘
```

### Landscape Mode (iPad)
```
Same 2×2 grid (wider cards):
┌─────────┬─────────┐
│   24    │   45    │
├─────────┼─────────┤
│  18/24  │   ∞     │
└─────────┴─────────┘
```

Both adapt when hidden!

---

## Code Efficiency

**Before:** Info cards rendered every time
```swift
LazyVGrid { ... }  // Always renders
```

**After:** Info cards conditionally rendered
```swift
if attempts.isEmpty {
    LazyVGrid { ... }  // Only renders when needed
}
```

**Memory savings:** ~240px of UI components not rendered for returning users

---

**Status:** ✅ Implementation Complete
**Testing:** Ready for manual UI testing
**Animation:** Smooth fade + scale transition
**Performance:** Improved (conditional rendering)
