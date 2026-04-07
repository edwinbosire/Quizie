# QuizLobbyView Info Cards Update

## Summary of Changes

Updated `QuizLobbyView.swift` to hide the info cards grid once a user has attempted at least one exam.

## What Changed

### Before
The info cards (24 Questions, 45 Minutes, 18/24 Pass Mark, ∞ Random) were always visible, regardless of whether the user had taken any exams.

### After
The info cards now only appear for first-time users who haven't attempted any exams yet. Once they complete their first exam, the cards disappear and are replaced by the Performance Summary and Recent Attempts sections.

## Implementation Details

### Conditional Rendering
```swift
// Info cards grid (only show for first-time users)
if attempts.isEmpty {
    LazyVGrid(columns: [...]) {
        // 4 InfoCard components
    }
    .transition(.asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.95)),
        removal: .opacity.combined(with: .scale(scale: 0.95))
    ))
}
```

### Key Changes
1. **Added conditional**: Wrapped the `LazyVGrid` with `if attempts.isEmpty`
2. **Added smooth transition**: Cards fade out with a subtle scale effect when they disappear
3. **Updated comment**: Changed from "Info cards grid" to "Info cards grid (only show for first-time users)"

## User Experience

### First-Time User (No Attempts)
```
┌─────────────────────────────────────┐
│  🎯 PRACTICE TEST                   │
│  Life in the UK Practice Exam       │
│  Test your knowledge...             │
└─────────────────────────────────────┘

┌───────────┬───────────┐
│  📝 24    │  ⏰ 45    │  ← These info cards
│ Questions │  Minutes  │     are visible
├───────────┼───────────┤
│  ✓ 18/24  │  🔀 ∞    │
│ Pass Mark │  Random   │
└───────────┴───────────┘

┌─────────────────────────────────────┐
│  BEFORE YOU START                   │
│  1. Read each question carefully... │
│  2. Some questions require TWO...   │
│  3. You cannot go back...           │
│  4. The exam ends when...           │
└─────────────────────────────────────┘

[Start Practice Exam]
```

### Returning User (With Attempts)
```
┌─────────────────────────────────────┐
│  🎯 PRACTICE TEST                   │
│  Life in the UK Practice Exam       │
│  Test your knowledge...             │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  YOUR PROGRESS              3       │  ← Performance summary
│  Great work! Keep practicing... ATTEMPTS│  replaces info cards
│                                     │
│  📊 75%    🏆 22/24    ✅ 66%     │
│  Avg Score  Best Score  Pass Rate   │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  RECENT ATTEMPTS                    │  ← Recent attempts
│  ✓ Passed    22/24    2 min ago    │     section appears
│  ✗ Not Passed 16/24   1 day ago    │
│  ✓ Passed    20/24    3 days ago   │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  BEFORE YOU START                   │
│  1. Read each question carefully... │
│  2. Some questions require TWO...   │
│  3. You cannot go back...           │
│  4. The exam ends when...           │
└─────────────────────────────────────┘

[Try Another Exam]
```

## Benefits

### 1. **Reduced Clutter**
- Returning users don't need to see basic exam info repeatedly
- Screen space is better utilized for relevant statistics

### 2. **Progressive Disclosure**
- New users get essential information upfront
- Experienced users see their performance metrics instead

### 3. **Better Visual Hierarchy**
- Performance Summary takes center stage for returning users
- Creates a sense of progression and achievement

### 4. **Smooth Transitions**
- Subtle fade and scale animation makes the change feel natural
- Prevents jarring layout shifts

## Technical Implementation

### Data Query
The view uses SwiftData's `@Query` to fetch all exam attempts:
```swift
@Query(sort: \ExamAttempt.attemptDate, order: .reverse) 
private var attempts: [ExamAttempt]
```

### Conditional Logic
```swift
if attempts.isEmpty {
    // Show info cards
} else {
    // Cards automatically hidden
    // Performance summary shown instead
}
```

### Animation
The transition uses SwiftUI's `.asymmetric` transition combining:
- **Opacity**: Smooth fade in/out
- **Scale**: Subtle zoom effect (95% scale)
- Applied to both insertion and removal for consistency

## Testing Scenarios

### Test Case 1: New User
1. Launch app with no exam history
2. Navigate to Quiz Lobby
3. ✅ Should see 4 info cards (24 Questions, 45 Minutes, etc.)
4. ✅ Should see "Start Practice Exam" button

### Test Case 2: After First Exam
1. Complete first practice exam
2. Return to Quiz Lobby
3. ✅ Info cards should disappear
4. ✅ Performance Summary should appear
5. ✅ Recent Attempts should show 1 attempt
6. ✅ Button should say "Try Another Exam"

### Test Case 3: Multiple Exams
1. Complete multiple exams
2. Return to Quiz Lobby
3. ✅ Info cards should remain hidden
4. ✅ Performance Summary should show accurate stats
5. ✅ Recent Attempts should show last 3 attempts

### Test Case 4: Animation
1. Complete first exam (in a testing scenario where you can observe the lobby during completion)
2. Observe the transition
3. ✅ Cards should fade out smoothly
4. ✅ No abrupt layout jumps

## Edge Cases Handled

### Empty State
- When `attempts.isEmpty == true`
- Info cards display properly
- No performance summary shown

### Single Attempt
- When `attempts.count == 1`
- Info cards hidden
- Performance Summary shows (even with just 1 attempt)
- Recent Attempts shows 1 item

### Many Attempts
- When `attempts.count > 3`
- Info cards hidden
- Performance Summary shows aggregate stats
- Recent Attempts limited to 3 most recent

## Code Quality

- ✅ Clear, self-documenting code
- ✅ Consistent with existing code style
- ✅ Proper use of SwiftUI conditionals
- ✅ Smooth animations enhance UX
- ✅ No breaking changes to other components

## Related Components

These components remain unchanged but work together:
- `PerformanceSummary` - Shows when attempts exist
- `RecentAttemptsList` - Shows when attempts exist
- `RulesCard` - Always visible
- `LobbyHero` - Always visible
- `InfoCard` - Now conditionally rendered

## Future Enhancements (Optional)

Consider adding:
- 🔄 Option to toggle info cards back on (settings toggle)
- 📊 Expandable info cards in Performance Summary
- 💡 First-time onboarding overlay with tips
- 🎨 Different animations based on pass/fail status
- 📈 More detailed statistics view

## Accessibility

The change maintains accessibility:
- ✅ All components remain VoiceOver compatible
- ✅ No impact on Dynamic Type
- ✅ Color contrast preserved
- ✅ Semantic structure maintained

## Performance Impact

- ✅ Minimal: Single conditional check
- ✅ No additional queries or computations
- ✅ SwiftUI efficiently handles conditional rendering
- ✅ Transition animations are GPU-accelerated

---

**Change Type**: UI Enhancement
**Risk Level**: Low
**Testing Required**: Manual UI testing
**Backward Compatible**: Yes
**Database Changes**: None
