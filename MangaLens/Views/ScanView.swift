import SwiftUI
import AVFoundation
import PhotosUI

struct ScanView: View {

    @EnvironmentObject var manager: TranslationManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ScanTab = .screenshot
    @State private var capturedImage: UIImage? = nil
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var showResults = false

    enum ScanTab: String, CaseIterable {
        case camera    = "Camera"
        case screenshot = "Screenshot"
        case live      = "Live"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Scan Mode", selection: $selectedTab) {
                    ForEach(ScanTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 12)

                ZStack {
                    switch selectedTab {
                    case .camera:
                        CameraTabView(onCapture: handleCapture)
                    case .screenshot:
                        ScreenshotTabView(
                            capturedImage: $capturedImage,
                            photoPickerItem: $photoPickerItem,
                            onTranslate: handleTranslate
                        )
                    case .live:
                        LiveScanView()
                            .environmentObject(manager)
                    }

                    // Loading overlay (camera / screenshot only)
                    if manager.isTranslating && selectedTab != .live {
                        loadingOverlay
                    }

                    // Results overlay (camera / screenshot)
                    if showResults,
                       let image = capturedImage,
                       !manager.currentResults.isEmpty,
                       selectedTab != .live {
                        TranslationOverlayView(image: image, results: manager.currentResults)
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        Task { if manager.isLiveMode { await manager.stopLiveMode() } }
                        dismiss()
                    }
                }
                if showResults && !manager.currentResults.isEmpty && selectedTab != .live {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(manager.errorMessage != nil && !manager.isTranslating)) {
                Button("OK") { manager.errorMessage = nil }
            } message: {
                Text(manager.errorMessage ?? "")
            }
            .onChange(of: selectedTab) { _, newTab in
                // Stop live mode if user switches away from Live tab
                if newTab != .live && manager.isLiveMode {
                    Task { await manager.stopLiveMode() }
                }
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.4).tint(.white)
                Text("Translating...").foregroundColor(.white).font(.subheadline).fontWeight(.medium)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Handlers

    private func handleCapture(_ image: UIImage) {
        capturedImage = image
        handleTranslate(image)
    }

    private func handleTranslate(_ image: UIImage) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showResults = false
        Task {
            await manager.processImage(image)
            if !manager.currentResults.isEmpty {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showResults = true
                }
            }
        }
    }
}

// MARK: - Screenshot Tab

private struct ScreenshotTabView: View {

    @Binding var capturedImage: UIImage?
    @Binding var photoPickerItem: PhotosPickerItem?
    let onTranslate: (UIImage) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)
                    .padding(.horizontal)

                Button {
                    onTranslate(image)
                } label: {
                    Label("Translate", systemImage: "doc.text.magnifyingglass")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(14)
                        .padding(.horizontal)
                }
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)

                Text("Select a manga screenshot\nto translate")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Label(
                    capturedImage == nil ? "Select from Photos" : "Choose Different Photo",
                    systemImage: "photo.badge.plus"
                )
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)
                .padding(.horizontal)
            }
            .onChange(of: photoPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImage = image
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - Camera Tab

private struct CameraTabView: View {

    let onCapture: (UIImage) -> Void

    var body: some View {
        ZStack {
            CameraPreview(onCapture: onCapture)
                .ignoresSafeArea(edges: .bottom)
            CornerBracketsView().padding(40)
            VStack {
                Spacer()
                Button {
                    NotificationCenter.default.post(name: .capturePhoto, object: nil)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 4).frame(width: 84, height: 84))
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

private struct CameraPreview: UIViewRepresentable {

    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let session = AVCaptureSession()
        session.sessionPreset = .photo
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return view }

        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) { session.addOutput(output) }
        context.coordinator.photoOutput = output

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        context.coordinator.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.capturePhoto), name: .capturePhoto, object: nil)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { context.coordinator.previewLayer?.frame = uiView.bounds }
    }

    final class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        var session: AVCaptureSession?
        var photoOutput: AVCapturePhotoOutput?
        var previewLayer: AVCaptureVideoPreviewLayer?
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        @objc func capturePhoto() { photoOutput?.capturePhoto(with: AVCapturePhotoSettings(), delegate: self) }

        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self.onCapture(image) }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            session?.stopRunning()
        }
    }
}

// MARK: - Corner Brackets Guide

private struct CornerBracketsView: View {
    let length: CGFloat = 28
    let thickness: CGFloat = 3
    let color: Color = .white.opacity(0.8)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                corner(rotation: 0).position(x: 0, y: 0)
                corner(rotation: 90).position(x: geo.size.width, y: 0)
                corner(rotation: 270).position(x: 0, y: geo.size.height)
                corner(rotation: 180).position(x: geo.size.width, y: geo.size.height)
            }
        }
    }

    private func corner(rotation: Double) -> some View {
        ZStack {
            Rectangle().fill(color).frame(width: length, height: thickness).offset(x: length/2, y: thickness/2)
            Rectangle().fill(color).frame(width: thickness, height: length).offset(x: thickness/2, y: length/2)
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Notification

extension Notification.Name {
    static let capturePhoto = Notification.Name("MangaLens.capturePhoto")
}

// MARK: - Preview

#if DEBUG
#Preview {
    ScanView().environmentObject(TranslationManager())
}
#endif
