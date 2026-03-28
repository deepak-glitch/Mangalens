import SwiftUI

/// Renders a source image and positions TranslationBubble views
/// **directly on top of** each detected speech bubble — covering the
/// original text and replacing it with the English translation.
struct TranslationOverlayView: View {

    let image: UIImage
    let results: [TranslationResult]

    @State private var visibleIDs: Set<UUID>

    init(image: UIImage, results: [TranslationResult]) {
        self.image = image
        self.results = results
        _visibleIDs = State(initialValue: Set(results.map { $0.id }))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // ── Base image ──────────────────────────────────────────────
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width)

                // ── Translation bubbles ──────────────────────────────────────
                // Each bubble is positioned and sized to COVER the original
                // speech bubble text, replacing Korean/Japanese with English.
                ForEach(results) { result in
                    if visibleIDs.contains(result.id) {
                        let frame = bubbleFrame(for: result, in: geo.size)

                        TranslationBubble(
                            result: result,
                            targetSize: frame.size,
                            onDismiss: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    visibleIDs.remove(result.id)
                                }
                            }
                        )
                        // Position anchors the view's CENTER at the bubble midpoint.
                        // This places the overlay exactly over the speech bubble.
                        .position(x: frame.midX, y: frame.midY)
                        .onAppear {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Coordinate Mapping
    //
    // Vision returns bounding boxes in a normalised coordinate system
    // where (0,0) is the BOTTOM-LEFT of the image and values go 0→1.
    //
    // UIKit/SwiftUI uses TOP-LEFT as (0,0).
    //
    // So given Vision box {x, y, w, h}:
    //   screenX = x  * displayedWidth  + offsetX
    //   screenY = (1 - y - h) * displayedHeight + offsetY    ← Y flip
    //   screenW = w  * displayedWidth
    //   screenH = h  * displayedHeight
    //
    // We also need to account for aspect-ratio letterboxing/pillarboxing
    // because scaledToFit() may add empty space around the image.
    //
    private func bubbleFrame(for result: TranslationResult, in containerSize: CGSize) -> CGRect {
        let box = result.cgBoundingBox

        let imgAspect = image.size.width / max(image.size.height, 1)
        let conAspect = containerSize.width / max(containerSize.height, 1)

        let displayedWidth: CGFloat
        let displayedHeight: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if imgAspect > conAspect {
            // Image is wider than container → pillarbox (bars on top/bottom)
            displayedWidth  = containerSize.width
            displayedHeight = containerSize.width / imgAspect
            offsetX = 0
            offsetY = (containerSize.height - displayedHeight) / 2
        } else {
            // Image is taller than container → letterbox (bars on left/right)
            displayedHeight = containerSize.height
            displayedWidth  = containerSize.height * imgAspect
            offsetX = (containerSize.width - displayedWidth) / 2
            offsetY = 0
        }

        // Apply Vision → UIKit coordinate transform
        let x = offsetX + box.origin.x * displayedWidth
        let y = offsetY + (1 - box.origin.y - box.height) * displayedHeight
        let w = max(box.width  * displayedWidth,  80)   // minimum 80 pt wide
        let h = max(box.height * displayedHeight, 36)   // minimum 36 pt tall

        return CGRect(x: x, y: y, width: w, height: h)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    TranslationOverlayView(
        image: UIImage(systemName: "photo")!,
        results: TranslationResult.sampleData
    )
    .frame(height: 400)
    .padding()
}
#endif
