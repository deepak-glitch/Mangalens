import SwiftUI

struct TranslationOverlayView: View {

    let image: UIImage
    let results: [TranslationResult]

    @State private var visibleIDs: Set<UUID>
    @State private var imageSize: CGSize = .zero

    init(image: UIImage, results: [TranslationResult]) {
        self.image = image
        self.results = results
        _visibleIDs = State(initialValue: Set(results.map { $0.id }))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Base image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width)
                    .background(
                        GeometryReader { imgGeo in
                            Color.clear
                                .onAppear {
                                    imageSize = imgGeo.size
                                }
                        }
                    )

                // Translation bubble overlays
                ForEach(results) { result in
                    if visibleIDs.contains(result.id) {
                        let frame = bubbleFrame(for: result, in: geo.size)

                        TranslationBubble(result: result) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                visibleIDs.remove(result.id)
                            }
                        }
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

    /// Maps Vision's normalized bounding box (bottom-left origin) to
    /// a position within the displayed image frame inside the GeometryReader.
    private func bubbleFrame(for result: TranslationResult, in containerSize: CGSize) -> CGRect {
        let box = result.cgBoundingBox

        // Fit-scale factor
        let imgAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        let displayedWidth: CGFloat
        let displayedHeight: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if imgAspect > containerAspect {
            displayedWidth = containerSize.width
            displayedHeight = containerSize.width / imgAspect
            offsetX = 0
            offsetY = (containerSize.height - displayedHeight) / 2
        } else {
            displayedHeight = containerSize.height
            displayedWidth = containerSize.height * imgAspect
            offsetX = (containerSize.width - displayedWidth) / 2
            offsetY = 0
        }

        // Vision box: origin bottom-left, flip Y
        let x = offsetX + box.origin.x * displayedWidth
        let y = offsetY + (1 - box.origin.y - box.height) * displayedHeight
        let w = box.width * displayedWidth
        let h = box.height * displayedHeight

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
