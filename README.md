# Quizie

Quizie is a native SwiftUI iOS app for preparing for the **Life in the UK** test.  
It combines a full handbook reader, timed practice exams, keyword search, highlights, and progress tracking in one app.

## What the App Includes

- **Onboarding flow** introducing study, testing, and progress features.
- **Handbook reader** with chapter/section navigation and rich content blocks.
- **Practice quiz engine** with timed exams, instant answer feedback, and pass/fail results.
- **Search experience** across handbook content with snippets and highlighted matches.
- **Persistent progress** using SwiftData for:
  - Exam attempt history
  - Chapter reading progress
  - Reader highlights
- **Custom design system** (colors, typography, spacing, component styling) tuned for readability.

## Main User Flows

### 1) Study the handbook
Users browse chapters, open sections, read formatted content, and track completion/reading time.

### 2) Take practice exams
Users start a timed exam (24 questions, 45 minutes), answer randomized questions, and review detailed results.

### 3) Review progress
Users can return to see prior attempts, score trends, pass rate, reading time, and recent activity.

### 4) Search quickly
Users can search handbook topics from a dedicated tab and jump directly to relevant sections.

## Project Structure

```text
Quizie/
├── Quizie/                               # Main app target
│   ├── HandbookReaderQuizApp.swift       # App entry + tab root
│   ├── Info.plist
│   ├── Assets.xcassets/
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── Handbook/
│   │   ├── HandbookView.swift
│   │   ├── ChapterView.swift
│   │   ├── HandbookData.swift
│   │   ├── ReadingProgress.swift
│   │   ├── Highlight.swift
│   │   └── handbook.json
│   ├── Quiz/
│   │   ├── QuizRootView.swift
│   │   ├── QuizLobbyView.swift
│   │   ├── QuizEngine.swift
│   │   ├── QuizQuestionView.swift
│   │   ├── QuizResultsView.swift
│   │   ├── QuizModels.swift
│   │   ├── ExamAttempt.swift
│   │   └── questions.json
│   ├── Search/
│   │   └── SearchView.swift
│   └── Resources/
│       ├── Animation.swift
│       └── Fonts/
├── QuizieTests/                          # Unit test target scaffold
├── QuizieUITests/                        # UI test target scaffold
├── Quizie.xcodeproj
└── screenshots/
    └── appstore-screenshots.html
```

## Architecture Overview

- **UI:** SwiftUI (`TabView`, `NavigationStack`, reusable view components)
- **State management:** `@State`, `@StateObject`, `@EnvironmentObject`, `@Observable`
- **Persistence:** SwiftData models (`ExamAttempt`, `ReadingProgress`, `Highlight`)
- **Data sources:** Local bundled JSON files (`handbook.json`, `questions.json`)
- **Quiz runtime:** `QuizEngine` controls phases (lobby → question → results), timer, scoring, and persistence

## Core Domain Models

- `ExamSession` – in-memory active exam state
- `QuizQuestion` – normalized question model loaded from `questions.json`
- `ExamAttempt` – persisted exam history
- `ReadingProgress` – persisted chapter progress + reading time
- `Highlight` – persisted user highlights in handbook content

## Design & Content

- Uses a consistent visual language defined in `Handbook/DesignSystem.swift`.
- Uses native SwiftUI text styles and system font designs for Dynamic Type support.
- Handbook content is parsed from lightweight HTML-like content blocks in JSON.

## Requirements

- Xcode (latest stable recommended)
- iOS Simulator or physical iOS device
- Swift toolchain bundled with Xcode

> Note: This repository is an Xcode iOS app project (not a Swift Package), so `swift build` / `swift test` from repo root are not the primary build path.

## Getting Started

1. Open `Quizie.xcodeproj` in Xcode.
2. Select the **Quizie** scheme.
3. Choose an iOS Simulator device (for example, iPhone 15).
4. Build and run (`⌘R`).

## Running Tests

From Xcode:

1. Select the **Quizie** scheme.
2. Run tests (`⌘U`).

Current repository includes starter unit/UI test targets that can be expanded with feature-specific tests.

## CI

GitHub Actions workflow is defined at:

- `.github/workflows/swift.yml`

It currently uses `swift build` and `swift test`, which is best suited for Swift Package projects.
For this Xcode-based iOS app, CI is typically configured with `xcodebuild build` and `xcodebuild test`
against the `Quizie` scheme and a simulator destination.

## Additional Project Docs

- `Quizie/Quiz/README.md` – quiz module notes
- `Quizie/Handbook/QUICK_REFERENCE.md` – handbook/progress notes
- `screenshots/appstore-screenshots.html` – App Store screenshot composition page
