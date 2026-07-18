import SwiftUI

struct HandbookView: View {
	let dependencies: HandbookFeatureDependencies
	private var catalog: HandbookCatalog { dependencies.catalog }

	var body: some View {
		Group {
			if let error = catalog.error {
				RepositoryErrorView(title: "Handbook Unavailable", error: error, retry: catalog.reload)
			} else {
				ScrollView {
					ChapterList(chapters: catalog.chapters)
						.staggered(0.2)
				}
				.background(Color.hbBackground)
				.ignoresSafeArea(edges: .top)
				.navigationBarHidden(true)
			}
		}
		.environment(dependencies.catalog)
		.environment(dependencies.progress)
		.environment(dependencies.highlights)
	}
}

struct RepositoryErrorView: View {
	let title: String
	let error: ContentRepositoryError
	let retry: () -> Void

	var body: some View {
		ContentUnavailableView {
			Label(title, systemImage: "exclamationmark.triangle")
		} description: {
			Text(error.localizedDescription)
		} actions: {
			Button("Try Again", action: retry)
				.buttonStyle(.borderedProminent)
		}
	}
}

// MARK: - Hero Header
