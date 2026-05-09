//
//  Animation.swift
//  Quizie
//
//  Created by Edwin Bosire on 09/05/2026.
//

import SwiftUI

extension View {
	func staggered(_ delay: Double = 0.1, repeats: Bool = false) -> some View {
		modifier(StaggeredAnimationModifier(delay: delay, repeats: repeats))
	}
}

struct StaggeredAnimationModifier: ViewModifier {
	@State private var offset: CGFloat = 20.0
	@State private var opacity: Double = 0.0
	@State private var shouldRepeatAnimation: Bool = true

	var delay: Double
	var repeats: Bool

	func body(content: Content) -> some View {
		content
			.offset(y: offset)
			.opacity(opacity)
			.onAppear {
				guard shouldRepeatAnimation else { return }
				withAnimation(.easeOut(duration: 0.2).delay(delay)) {
					opacity = 1.0
				}

				withAnimation(.easeInOut(duration: 0.4).delay(delay)) {
					offset = 0.0
				}
				shouldRepeatAnimation = repeats

			}
			.onDisappear {
				guard shouldRepeatAnimation else { return }
				opacity = 0.0
				offset = 20.0

			}
	}
}

