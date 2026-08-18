//
//  HandbookReaderQuizUITests.swift
//  HandbookReaderQuizUITests
//
//  Created by Edwin Bosire on 28/03/2026.
//

import XCTest

final class HandbookReaderQuizUITests: XCTestCase {

    private struct AppStoreScene {
        let index: Int
        let name: String
        let tab: String
    }

    private let appStoreScenes = [
        AppStoreScene(index: 1, name: "home", tab: "Home"),
        AppStoreScene(index: 2, name: "tests", tab: "Tests"),
        AppStoreScene(index: 3, name: "flashcards", tab: "Flashcards"),
        AppStoreScene(index: 4, name: "handbook", tab: "Handbook"),
        AppStoreScene(index: 5, name: "search", tab: "Search"),
    ]

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testAppStoreScreenshotsLight() throws {
        try captureAppStoreScreenshots(appearance: "light")
    }

    @MainActor
    func testAppStoreScreenshotsDark() throws {
        try captureAppStoreScreenshots(appearance: "dark")
    }

    @MainActor
    private func captureAppStoreScreenshots(appearance: String) throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB",
            "-AppleInterfaceStyle", appearance.capitalized,
        ]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "The main tab bar did not appear")

        for scene in appStoreScenes {
            let tab = tabBar.buttons[scene.tab]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing \(scene.tab) tab")
            tab.tap()

            // Give animated tab transitions and async content one beat to settle.
            let settled = expectation(description: "Wait for \(scene.name) to settle")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { settled.fulfill() }
            wait(for: [settled], timeout: 2)

            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = String(format: "%02d-%@-%@", scene.index, scene.name, appearance)
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testHandbookTabReceivesExplicitDependencies() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        app.tabBars.buttons["Handbook"].tap()

        XCTAssertTrue(app.staticTexts["CHAPTERS"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTestsEmptyStateStartsFirstTest() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        app.tabBars.buttons["Tests"].tap()

        let startButton = app.buttons["tests.startFirst"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["YOUR STATISTICS"].exists)
        startButton.tap()

        XCTAssertTrue(app.buttons["Quiz options"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHandbookReaderHeaderExposesNavigationControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        app.tabBars.buttons["Handbook"].tap()

        let firstChapter = app.staticTexts["The values and principles of the UK"].firstMatch
        XCTAssertTrue(firstChapter.waitForExistence(timeout: 5))
        firstChapter.tap()

        XCTAssertTrue(app.buttons["Back to handbook contents"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Choose chapter"].exists)
        XCTAssertTrue(app.buttons["Reader settings"].exists)

        let chapterTitle = app.staticTexts["reader.chapterHeader.title"]
        XCTAssertTrue(chapterTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(chapterTitle.isHittable, "The chapter header should be visible below the reader controls")
    }

    @MainActor
    func testChapterRevisionCreatesFlashcardsAndStartsSectionPractice() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-uiTestChapterRevision"]
        app.launch()

        app.tabBars.buttons["Handbook"].tap()
        let firstChapter = app.staticTexts["The values and principles of the UK"].firstMatch
        XCTAssertTrue(firstChapter.waitForExistence(timeout: 5))
        firstChapter.tap()

        XCTAssertTrue(app.staticTexts["handbook.chapterRevision.heading"].waitForExistence(timeout: 5))
        let flashcards = app.buttons["handbook.revision.flashcards.section_01_01"]
        XCTAssertTrue(flashcards.waitForExistence(timeout: 5))
        flashcards.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        let practice = app.buttons["handbook.revision.practice.section_01_01"]
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        practice.tap()

        XCTAssertTrue(app.buttons["Quiz options"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["quiz.taxonomy"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    @MainActor
    func testMainNavigationBarRoutesAndHidesCurrentDestination() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let searchButton = app.buttons["mainNavigation.search"]
        let handbookButton = app.buttons["mainNavigation.handbook"]
        let settingsButton = app.buttons["mainNavigation.settings"]

        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        XCTAssertTrue(handbookButton.exists)
        XCTAssertTrue(settingsButton.exists)

        searchButton.tap()

        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))
        XCTAssertFalse(searchButton.exists)
        XCTAssertTrue(handbookButton.exists)

        handbookButton.tap()

        XCTAssertTrue(app.navigationBars["Handbook"].waitForExistence(timeout: 5))
        XCTAssertFalse(handbookButton.exists)
        XCTAssertTrue(searchButton.exists)

        settingsButton.tap()
        XCTAssertTrue(app.staticTexts["TEXT SIZE"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReaderTextSizePresetPersists() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let settingsButton = app.buttons["mainNavigation.settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        app.tabBars.buttons["Handbook"].tap()
        XCTAssertTrue(app.navigationBars["Handbook"].waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.scrollViews["reader.settings"].waitForExistence(timeout: 5))
        let smallOption = app.buttons["reader.textSize.small"]
        let standardOption = app.buttons["reader.textSize.standard"]
        let largeOption = app.buttons["reader.textSize.large"]
        let previewText = app.staticTexts["The United Kingdom"]
        XCTAssertTrue(previewText.waitForExistence(timeout: 5))

        standardOption.tap()
        XCTAssertTrue(standardOption.isSelected)

        smallOption.tap()
        XCTAssertTrue(smallOption.isSelected)
        let smallPreviewWidth = previewText.frame.width

        standardOption.tap()
        XCTAssertTrue(standardOption.isSelected)

        XCTAssertTrue(largeOption.waitForExistence(timeout: 5))
        largeOption.tap()
        XCTAssertTrue(largeOption.isSelected)
        XCTAssertGreaterThan(previewText.frame.width, smallPreviewWidth)

        app.terminate()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let reopenedSettingsButton = app.buttons["mainNavigation.settings"]
        XCTAssertTrue(reopenedSettingsButton.waitForExistence(timeout: 5))
        app.tabBars.buttons["Handbook"].tap()
        XCTAssertTrue(app.navigationBars["Handbook"].waitForExistence(timeout: 5))
        reopenedSettingsButton.tap()

        XCTAssertTrue(app.scrollViews["reader.settings"].waitForExistence(timeout: 5))
        let reopenedLargeOption = app.buttons["reader.textSize.large"]
        XCTAssertTrue(reopenedLargeOption.waitForExistence(timeout: 5))
        XCTAssertTrue(reopenedLargeOption.isSelected)
    }

    @MainActor
    func testAppearanceAppliesOutsideReader() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        app.tabBars.buttons["Handbook"].tap()
        XCTAssertTrue(app.navigationBars["Handbook"].waitForExistence(timeout: 5))
        app.buttons["mainNavigation.settings"].tap()

        XCTAssertTrue(app.scrollViews["reader.settings"].waitForExistence(timeout: 5))
        let smallOption = app.buttons["reader.textSize.small"]
        let sepiaOption = app.buttons["app.theme.sepia"]
        XCTAssertTrue(smallOption.waitForExistence(timeout: 5))
        XCTAssertTrue(sepiaOption.waitForExistence(timeout: 5))
        smallOption.tap()
        sepiaOption.tap()

        app.terminate()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let root = app.descendants(matching: .any)["app.root"]
        XCTAssertTrue(root.waitForExistence(timeout: 5))
        XCTAssertEqual(root.value as? String, "sepia-small")

        app.tabBars.buttons["Handbook"].tap()
        let chaptersHeading = app.staticTexts["handbook.chapters.heading"]
        XCTAssertTrue(chaptersHeading.waitForExistence(timeout: 5))
        let smallHeadingWidth = chaptersHeading.frame.width

        app.buttons["mainNavigation.settings"].tap()
        XCTAssertTrue(app.scrollViews["reader.settings"].waitForExistence(timeout: 5))
        app.buttons["reader.textSize.large"].tap()

        app.terminate()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        app.tabBars.buttons["Handbook"].tap()

        let largeChaptersHeading = app.staticTexts["handbook.chapters.heading"]
        XCTAssertTrue(largeChaptersHeading.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(largeChaptersHeading.frame.width, smallHeadingWidth)

        let updatedRoot = app.descendants(matching: .any)["app.root"]
        XCTAssertEqual(updatedRoot.value as? String, "sepia-large")
    }

    @MainActor
    func testQuittingQuizRestoresTabBar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let startButton = app.buttons["quiz.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let instructionsStartButton = app.buttons["quiz.instructions.start"]
        if instructionsStartButton.waitForExistence(timeout: 2) {
            instructionsStartButton.tap()
        }

        let optionsButton = app.buttons["Quiz options"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        optionsButton.tap()

        let quitQuizButton = app.buttons["Quit Quiz"]
        if !quitQuizButton.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(quitQuizButton.waitForExistence(timeout: 5))
        quitQuizButton.tap()

        let confirmQuitButton = app.alerts["Quit Quiz?"].buttons["Quit"]
        XCTAssertTrue(confirmQuitButton.waitForExistence(timeout: 5))
        confirmQuitButton.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
    }

    @MainActor
    func testExamHidesTaxonomyAndLocksHelpBeforeAnswering() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let startButton = app.buttons["quiz.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let instructionsStartButton = app.buttons["quiz.instructions.start"]
        if instructionsStartButton.waitForExistence(timeout: 2) {
            instructionsStartButton.tap()
        }

        XCTAssertFalse(app.buttons["quiz.taxonomy"].exists)

        let optionsButton = app.buttons["Quiz options"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5))
        optionsButton.tap()

        let hint = app.buttons["quiz.options.hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        XCTAssertFalse(hint.isEnabled)
        XCTAssertFalse(app.buttons["quiz.options.readInBook"].exists)
    }

    @MainActor
    func testReadInBookPresentsHandbookModally() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let streakButton = app.buttons["quiz.streak.start"]
        XCTAssertTrue(streakButton.waitForExistence(timeout: 5))
        streakButton.tap()

        let taxonomy = app.buttons["quiz.taxonomy"]
        XCTAssertTrue(taxonomy.waitForExistence(timeout: 5))
        taxonomy.tap()

        let hintNavigationBar = app.navigationBars["Handbook Hint"]
        XCTAssertTrue(hintNavigationBar.waitForExistence(timeout: 5))

        let showInHandbook = app.buttons["quiz.hint.openHandbook"]
        XCTAssertTrue(showInHandbook.waitForExistence(timeout: 5))
        showInHandbook.tap()

        let closeHandbook = app.buttons["Close handbook"]
        XCTAssertTrue(closeHandbook.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Back to handbook contents"].exists)
        closeHandbook.tap()

        let optionsButton = app.buttons["Quiz options"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5))
        optionsButton.tap()

        let readInBook = app.buttons["quiz.options.readInBook"]
        XCTAssertTrue(readInBook.waitForExistence(timeout: 5))
        readInBook.tap()

        XCTAssertTrue(app.buttons["Close handbook"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Back to handbook contents"].exists)
    }

    @MainActor
    func testQuittingPracticeTestDismissesFullScreenQuiz() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let testsTab = app.tabBars.buttons["Tests"]
        XCTAssertTrue(testsTab.waitForExistence(timeout: 5))
        testsTab.tap()

        let firstTest = app.staticTexts["Practice Test 1"]
        XCTAssertTrue(firstTest.waitForExistence(timeout: 5))
        firstTest.tap()

        let optionsButton = app.buttons["Quiz options"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5))
        optionsButton.tap()

        let quitQuizButton = app.buttons["Quit Quiz"]
        XCTAssertTrue(quitQuizButton.waitForExistence(timeout: 5))
        quitQuizButton.tap()

        let confirmQuitButton = app.alerts["Quit Quiz?"].buttons["Quit"]
        XCTAssertTrue(confirmQuitButton.waitForExistence(timeout: 5))
        confirmQuitButton.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(testsTab.isSelected)
    }

    @MainActor
    func testCompletedPracticeTestReturnsToMainHomeChrome() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-uiTestSingleQuestion",
        ]
        app.launch()

        app.tabBars.buttons["Tests"].tap()
        app.staticTexts["Practice Test 1"].tap()

        let firstChoice = app.buttons["quiz.choice.0"]
        XCTAssertTrue(firstChoice.waitForExistence(timeout: 5))
        firstChoice.tap()

        let submitExam = app.buttons["Submit Exam"]
        if submitExam.waitForExistence(timeout: 2) {
            submitExam.tap()
        }

        let returnHome = app.buttons["Return to Home"]
        XCTAssertTrue(returnHome.waitForExistence(timeout: 8))
        returnHome.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Home"].isSelected)
        XCTAssertTrue(app.buttons["mainNavigation.settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMatchingGameLaunchesFromHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let homeCard = app.buttons["matchGame.homeCard"]
        var swipeCount = 0
        while !homeCard.isHittable && swipeCount < 3 {
            app.swipeUp()
            swipeCount += 1
        }

        XCTAssertTrue(homeCard.waitForExistence(timeout: 5))
        XCTAssertTrue(homeCard.isHittable)
        homeCard.tap()

        XCTAssertTrue(app.staticTexts["Ready to match?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["matchGame.howToPlay"].exists)
        XCTAssertTrue(app.staticTexts["Drag or tap two cards"].exists)
        XCTAssertTrue(app.staticTexts["Correct pairs stay matched"].exists)
        XCTAssertTrue(app.staticTexts["Wrong pair? Keep going"].exists)
        XCTAssertTrue(app.tabBars.firstMatch.waitForNonExistence(timeout: 5))
        app.buttons["matchGame.start"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["matchGame.timer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 of 6 matched"].exists)
    }

    @MainActor
    func testFlashcardStatisticsCardLaunchesFromHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let homeCard = app.buttons["flashcards.homeCard"]
        var swipeCount = 0
        while !homeCard.isHittable && swipeCount < 3 {
            app.swipeUp()
            swipeCount += 1
        }

        XCTAssertTrue(homeCard.waitForExistence(timeout: 5))
        XCTAssertTrue(homeCard.isHittable)
        homeCard.tap()

        XCTAssertTrue(app.descendants(matching: .any)["flashcards.landing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.firstMatch.waitForNonExistence(timeout: 5))

        let chapterOne = app.buttons["flashcards.deck.chapter.1"]
        XCTAssertTrue(chapterOne.waitForExistence(timeout: 5))
        chapterOne.tap()

        XCTAssertTrue(app.descendants(matching: .any)["flashcards.study"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
