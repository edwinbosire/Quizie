# QuizLobbyView Update - Quick Summary

## What Was Changed

✅ **Info cards now hide after first exam attempt**

The 4 info cards (24 Questions, 45 Minutes, 18/24 Pass Mark, ∞ Random) now only display for first-time users. Once a user completes their first exam, these cards disappear.

## Single Code Change

### File: `QuizLobbyView.swift`

**Before:**
```swift
// Info cards grid
LazyVGrid(columns: [...]) {
    // 4 InfoCard components
}
.padding(.horizontal, 16)
.padding(.top, attempts.isEmpty ? 24 : 20)
```

**After:**
```swift
// Info cards grid (only show for first-time users)
if attempts.isEmpty {
    LazyVGrid(columns: [...]) {
        // 4 InfoCard components
    }
    .padding(.horizontal, 16)
    .padding(.top, 24)
    .transition(.asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.95)),
        removal: .opacity.combined(with: .scale(scale: 0.95))
    ))
}
```

## How It Works

### Detection
Uses the existing `@Query` for `ExamAttempt`:
```swift
@Query(sort: \ExamAttempt.attemptDate, order: .reverse) 
private var attempts: [ExamAttempt]
```

### Logic
- `attempts.isEmpty == true` → Show info cards
- `attempts.isEmpty == false` → Hide info cards

### Animation
Smooth fade + scale transition when cards appear/disappear

## UI Flow

### New User (No Exams)
```
Hero Section
   ↓
Info Cards (4 cards grid)    ← Visible
   ↓
Rules Card
   ↓
[Start Practice Exam]
```

### Returning User (Has Attempts)
```
Hero Section
   ↓
Performance Summary          ← Replaces info cards
   ↓
Recent Attempts (3 latest)
   ↓
Rules Card
   ↓
[Try Another Exam]
```

## Why This Improves UX

1. **Reduces Clutter**: Experienced users don't need basic info repeatedly
2. **Progressive Disclosure**: Shows relevant info based on user experience
3. **Better Use of Space**: Performance stats more valuable than static info
4. **Sense of Progress**: UI evolves with user's journey

## Testing

### Quick Test
1. Fresh install → Open Quiz → See info cards ✅
2. Complete one exam → Return → Cards gone, stats visible ✅
3. Complete more exams → Cards stay hidden ✅

## No Breaking Changes

- ✅ All other components unchanged
- ✅ No database schema changes
- ✅ Backward compatible
- ✅ Works with existing `ExamAttempt` model
- ✅ No impact on other views

## Related Views

These work together seamlessly:
- `PerformanceSummary` - Shows aggregate statistics
- `RecentAttemptsList` - Shows last 3 attempts
- `RulesCard` - Always visible (unchanged)
- `InfoCard` - Component reused, just conditionally rendered

---

**Ready to test!** The change is live and should work immediately.
