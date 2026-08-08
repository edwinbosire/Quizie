import SwiftUI

struct MyHighlightsCard: View {
	let highlightCount: Int

	var body: some View {
		HStack(spacing: 14) {
			ZStack {
				Circle()
					.fill(Color.hbAccent.opacity(0.12))
					.frame(width: 40, height: 40)

				Image(systemName: "highlighter")
					.font(.headline.weight(.semibold))
					.foregroundColor(.hbAccent)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text("My Highlights")
					.font(.subheadline.weight(.semibold))
					.foregroundColor(.hbTextPrimary)

				Text("\(highlightCount) highlight\(highlightCount == 1 ? "" : "s")")
					.font(.caption)
					.foregroundColor(.hbTextMuted)
			}

			Spacer()

			Image(systemName: "chevron.right")
				.font(.footnote.weight(.medium))
				.foregroundColor(.hbTextMuted.opacity(0.5))
		}
		.padding(16)
		.background(Color.hbSurface)
		.overlay(
			RoundedRectangle(cornerRadius: HBRadius.md)
				.stroke(Color.hbAccent.opacity(0.2), lineWidth: 1)
		)
		.clipShape(RoundedRectangle(cornerRadius: HBRadius.md))
	}
}

#Preview {
	let dependencies = try! AppDependencies.preview()
	HandbookView(dependencies: dependencies.handbook)
}
