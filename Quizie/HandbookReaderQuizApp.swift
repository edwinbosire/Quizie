//
//  HandbookReaderQuizApp.swift
//  HandbookReaderQuiz
//
//  Created by Edwin Bosire on 28/03/2026.
//

import SwiftUI

@main
struct HandbookReaderQuizApp: App {
    private let dependencies: AppDependencies

    init() {
        do {
            dependencies = try .production()
        } catch {
            fatalError("Unable to initialize persistence: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: dependencies)
        }
    }
}
