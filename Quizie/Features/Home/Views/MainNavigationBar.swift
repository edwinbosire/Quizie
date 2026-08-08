import SwiftUI

enum MainTab: String, Hashable {
	case home
	case tests
	case flashcards
	case handbook
	case search
}

private struct MainNavigationBarModifier: ViewModifier {
	let title: String
	let tab: MainTab
	let isVisible: Bool
	let onOpenSearch: () -> Void
	let onOpenHandbook: () -> Void
	let onOpenSettings: () -> Void

	func body(content: Content) -> some View {
		content
			.navigationTitle(isVisible ? title : "")
			.navigationBarTitleDisplayMode(.inline)
			.toolbarBackground(.hidden, for: .navigationBar)
			.toolbarRole(.browser)
			.toolbar {
				if isVisible {
					if tab != .handbook {
						ToolbarItem(placement: .topBarTrailing) {
							navigationButton(
								systemImage: "books.vertical.fill",
								label: "Handbook",
								identifier: "mainNavigation.handbook",
								action: onOpenHandbook
							)
						}
						ToolbarSpacer(.fixed, placement: .topBarTrailing)
					}

					if tab != .search {
						ToolbarItem(placement: .topBarTrailing) {
							navigationButton(
								systemImage: "magnifyingglass",
								label: "Search",
								identifier: "mainNavigation.search",
								action: onOpenSearch
							)
						}
					}


					ToolbarItem(placement: .topBarTrailing) {
						navigationButton(
							systemImage: "gearshape.fill",
							label: "Settings",
							identifier: "mainNavigation.settings",
							action: onOpenSettings
						)
					}
				}
			}
	}

	private func navigationButton(
		systemImage: String,
		label: String,
		identifier: String,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			Image(systemName: systemImage)
				.appFont(.subheadline)
		}
		.buttonStyle(.plain)
		.glassEffectTransition(.materialize)
		.glassEffect()
		.accessibilityLabel(label)
		.accessibilityIdentifier(identifier)
	}
}

extension View {
	func mainNavigationBar(
		title: String,
		tab: MainTab,
		isVisible: Bool = true,
		onOpenSearch: @escaping () -> Void,
		onOpenHandbook: @escaping () -> Void,
		onOpenSettings: @escaping () -> Void
	) -> some View {
		modifier(MainNavigationBarModifier(
			title: title,
			tab: tab,
			isVisible: isVisible,
			onOpenSearch: onOpenSearch,
			onOpenHandbook: onOpenHandbook,
			onOpenSettings: onOpenSettings
		))
	}
}
