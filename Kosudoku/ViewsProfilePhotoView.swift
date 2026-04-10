//
//  ProfilePhotoView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/9/26.
//

import SwiftUI
import PhotosUI

extension ProfileFrame {
    var gradientColors: [Color] {
        switch self {
        case .none: return [.clear]
        case .gold: return [Color.yellow, Color.orange, Color.yellow]
        case .diamond: return [Color.cyan, Color.white, Color.cyan]
        case .fire: return [Color.red, Color.orange, Color.yellow]
        case .bronzeGlow: return [Color(red: 0.8, green: 0.5, blue: 0.2), Color(red: 0.9, green: 0.7, blue: 0.3), Color(red: 0.8, green: 0.5, blue: 0.2)]
        case .silverShine: return [Color(red: 0.75, green: 0.75, blue: 0.8), Color.white, Color(red: 0.75, green: 0.75, blue: 0.8)]
        case .goldenAura: return [Color.yellow, Color.white, Color.yellow, Color.orange]
        case .rainbow: return [Color.red, Color.orange, Color.yellow, Color.green, Color.blue, Color.purple]
        case .pulseGold: return [Color.yellow, Color.orange, Color.yellow]
        case .shimmerDiamond: return [Color.cyan, Color.white, Color.cyan, Color.white]
        case .rotatingRainbow: return [Color.red, Color.orange, Color.yellow, Color.green, Color.blue, Color.purple]
        case .fireFlicker: return [Color.red, Color.orange, Color.yellow, Color.red]
        }
    }
}

/// Reusable profile photo component that displays user avatars
struct ProfilePhotoView: View {
    let imageData: Data?
    let displayName: String
    let size: CGFloat
    var profileFrame: ProfileFrame? = nil
    
    init(imageData: Data?, displayName: String, size: CGFloat = 40, profileFrame: ProfileFrame? = nil) {
        self.imageData = imageData
        self.displayName = displayName
        self.size = size
        self.profileFrame = profileFrame
    }
    
    var body: some View {
        Group {
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                // Display actual photo
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if displayName.isEmpty {
                // No name yet — show a generic person icon
                ZStack {
                    Circle()
                        .fill(Color(.systemGray4))
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
            } else {
                // Fallback to initials
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [colorForName(displayName), colorForName(displayName).opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text(initials(from: displayName))
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(Color(.systemBackground), lineWidth: 2)
        )
        .overlay(
            frameOverlay
        )
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var frameOverlay: some View {
        if let frame = profileFrame, frame != .none {
            if frame.isAnimated {
                AnimatedProfileFrameView(frame: frame, size: size)
            } else {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: frame.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(2, size * 0.06)
                    )
                    .frame(width: size + max(4, size * 0.1), height: size + max(4, size * 0.1))
            }
        }
    }
    
    // Generate initials from display name
    private func initials(from name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            let first = words[0].prefix(1)
            let last = words[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
    
    // Generate a consistent color based on name
    private func colorForName(_ name: String) -> Color {
        let colors: [Color] = [
            .blue, .purple, .pink, .red, .orange, 
            .yellow, .green, .teal, .cyan, .indigo
        ]
        
        let hash = name.hashValue
        let index = abs(hash) % colors.count
        return colors[index]
    }
}

/// Animated frame overlay for premium animated profile frames
struct AnimatedProfileFrameView: View {
    let frame: ProfileFrame
    let size: CGFloat
    
    @State private var animationProgress: CGFloat = 0
    
    private var lineWidth: CGFloat { max(2, size * 0.06) }
    private var frameSize: CGFloat { size + max(4, size * 0.1) }
    
    var body: some View {
        ZStack {
            switch frame {
            case .pulseGold:
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: frame.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
                    .frame(width: frameSize, height: frameSize)
                    .opacity(0.5 + 0.5 * animationProgress)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            animationProgress = 1
                        }
                    }
                    
            case .shimmerDiamond:
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: frame.gradientColors,
                            center: .center,
                            startAngle: .degrees(Double(animationProgress) * 360),
                            endAngle: .degrees(Double(animationProgress) * 360 + 360)
                        ),
                        lineWidth: lineWidth
                    )
                    .frame(width: frameSize, height: frameSize)
                    .onAppear {
                        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                            animationProgress = 1
                        }
                    }
                    
            case .rotatingRainbow:
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: frame.gradientColors + [frame.gradientColors.first ?? .red],
                            center: .center
                        ),
                        lineWidth: lineWidth
                    )
                    .frame(width: frameSize, height: frameSize)
                    .rotationEffect(.degrees(animationProgress * 360))
                    .onAppear {
                        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                            animationProgress = 1
                        }
                    }
                    
            case .fireFlicker:
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: frame.gradientColors,
                            startPoint: .bottom,
                            endPoint: .top
                        ),
                        lineWidth: lineWidth
                    )
                    .frame(width: frameSize, height: frameSize)
                    .opacity(0.7 + 0.3 * animationProgress)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                            animationProgress = 1
                        }
                    }
                    
            default:
                EmptyView()
            }
        }
    }
}

/// Editable profile photo picker with cropping
struct ProfilePhotoPicker: View {
    @Binding var imageData: Data?
    let size: CGFloat
    let displayName: String
    let enableCropper: Bool // Add option to disable cropper for testing
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var cropperImage: IdentifiableImage?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(imageData: Binding<Data?>, size: CGFloat, displayName: String, enableCropper: Bool = true) {
        self._imageData = imageData
        self.size = size
        self.displayName = displayName
        self.enableCropper = enableCropper
    }
    
    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                ProfilePhotoView(imageData: imageData, displayName: displayName, size: size)
                
                // Edit indicator
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: size * 0.3, height: size * 0.3)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.15))
                        .foregroundColor(.white)
                }
                .offset(x: -size * 0.05, y: -size * 0.05)
            }
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                guard let newValue else { return }
                
                do {
                    if let data = try await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        if enableCropper {
                            cropperImage = IdentifiableImage(image: uiImage)
                        } else {
                            if let compressed = compressImage(uiImage, maxSizeKB: 500) {
                                imageData = compressed
                            }
                            selectedItem = nil
                        }
                    } else {
                        errorMessage = "Failed to load image"
                        showingError = true
                        selectedItem = nil
                    }
                } catch {
                    errorMessage = "Error loading photo: \(error.localizedDescription)"
                    showingError = true
                    selectedItem = nil
                }
            }
        }
        .sheet(item: $cropperImage) { item in
            ImageCropperView(
                image: item.image,
                onCrop: { croppedImage in
                    if let compressed = compressImage(croppedImage, maxSizeKB: 500) {
                        imageData = compressed
                    }
                    cropperImage = nil
                    selectedItem = nil
                },
                onCancel: {
                    cropperImage = nil
                    selectedItem = nil
                }
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // Compress image to reduce storage/upload size
    private func compressImage(_ image: UIImage, maxSizeKB: Int) -> Data? {
        let maxBytes = maxSizeKB * 1024
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData, data.count > maxBytes, compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
}

/// Wrapper to make a UIImage usable with .sheet(item:)
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Simple image cropper for circular profile photos
struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let cropSize = min(geometry.size.width, geometry.size.height) - 80
                
                // Calculate the base size the image occupies when fitted into the view
                let imageAspect = image.size.width / image.size.height
                let viewAspect = geometry.size.width / geometry.size.height
                let fittedSize: CGSize = {
                    if imageAspect > viewAspect {
                        // Image is wider than view — limited by width
                        let w = geometry.size.width
                        return CGSize(width: w, height: w / imageAspect)
                    } else {
                        // Image is taller than view — limited by height
                        let h = geometry.size.height
                        return CGSize(width: h * imageAspect, height: h)
                    }
                }()
                
                // Initial scale so the image fills the crop circle
                let fillScale: CGFloat = {
                    let minFitted = min(fittedSize.width, fittedSize.height)
                    return minFitted > 0 ? cropSize / minFitted : 1.0
                }()
                
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    
                    // Image — rendered at fittedSize * scale, then offset
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale * fillScale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(lastScale * value, 0.5)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    
                    // Dimmed overlay with circular cutout
                    CropOverlay(cropSize: cropSize)
                        .allowsHitTesting(false)
                    
                    // Crop circle border
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropSize, height: cropSize)
                        .allowsHitTesting(false)
                }
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { _, newSize in
                    viewSize = newSize
                }
            }
            .background(Color.black)
            .navigationTitle("Adjust Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cropAndSave()
                    }
                    .foregroundColor(.white)
                    .bold()
                }
            }
        }
    }
    
    private func cropAndSave() {
        guard let croppedImage = cropImage() else {
            onCrop(image)
            return
        }
        onCrop(croppedImage)
    }
    
    private func cropImage() -> UIImage? {
        let outputSize: CGFloat = 500
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        
        let cropSize = min(viewSize.width, viewSize.height) - 80
        guard cropSize > 0 else { return nil }
        
        // Recalculate the same fitted size used in the view
        let imageAspect = image.size.width / image.size.height
        let viewAspect = viewSize.width / viewSize.height
        let fittedSize: CGSize
        if imageAspect > viewAspect {
            let w = viewSize.width
            fittedSize = CGSize(width: w, height: w / imageAspect)
        } else {
            let h = viewSize.height
            fittedSize = CGSize(width: h * imageAspect, height: h)
        }
        
        let fillScale: CGFloat = {
            let minFitted = min(fittedSize.width, fittedSize.height)
            return minFitted > 0 ? cropSize / minFitted : 1.0
        }()
        
        // The effective displayed size of the image (in screen points)
        let displayedWidth = fittedSize.width * scale * fillScale
        let displayedHeight = fittedSize.height * scale * fillScale
        
        // The image center on screen is the view center plus the drag offset
        let imageCenterX = viewSize.width / 2 + offset.width
        let imageCenterY = viewSize.height / 2 + offset.height
        
        // The crop circle center is always at the view center
        let cropCenterX = viewSize.width / 2
        let cropCenterY = viewSize.height / 2
        
        // How many screen points per source pixel
        let ptsPerPixelX = displayedWidth / image.size.width
        let ptsPerPixelY = displayedHeight / image.size.height
        
        // The crop circle's top-left in screen coordinates
        let cropOriginX = cropCenterX - cropSize / 2
        let cropOriginY = cropCenterY - cropSize / 2
        
        // Map the crop rectangle from screen points to source pixels
        let srcX = (cropOriginX - (imageCenterX - displayedWidth / 2)) / ptsPerPixelX
        let srcY = (cropOriginY - (imageCenterY - displayedHeight / 2)) / ptsPerPixelY
        let srcSize = cropSize / ptsPerPixelX  // circle is uniform, use X
        
        // Clamp to image bounds
        let sourceRect = CGRect(x: srcX, y: srcY, width: srcSize, height: srcSize)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize),
            format: format
        )
        
        return renderer.image { _ in
            // Circular clip
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: outputSize, height: outputSize)).addClip()
            
            // Draw the source region of the image into the output square
            image.draw(in: CGRect(
                x: -sourceRect.origin.x * (outputSize / sourceRect.width),
                y: -sourceRect.origin.y * (outputSize / sourceRect.height),
                width: image.size.width * (outputSize / sourceRect.width),
                height: image.size.height * (outputSize / sourceRect.height)
            ))
        }
    }
}

/// Dark overlay with a circular transparent cutout to highlight the crop area
struct CropOverlay: View {
    let cropSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(origin: .zero, size: geometry.size)
            let circleRect = CGRect(
                x: rect.midX - cropSize / 2,
                y: rect.midY - cropSize / 2,
                width: cropSize,
                height: cropSize
            )
            
            Canvas { context, _ in
                // Fill everything with semi-transparent black
                context.fill(Path(rect), with: .color(.black.opacity(0.5)))
                
                // Cut out the circle by clearing it
                context.blendMode = .destinationOut
                context.fill(Path(ellipseIn: circleRect), with: .color(.white))
            }
        }
        .compositingGroup()
    }
}

// MARK: - Preview Helpers

#Preview("Profile Photos - Various Sizes") {
    @Previewable @State var imageData: Data? = nil
    
    VStack(spacing: 20) {
        // With image
        ProfilePhotoView(
            imageData: UIImage(systemName: "person.fill")?.pngData(),
            displayName: "John Doe",
            size: 120
        )
        
        HStack(spacing: 16) {
            // Without image - different sizes
            ProfilePhotoView(imageData: nil, displayName: "Alice Smith", size: 80)
            ProfilePhotoView(imageData: nil, displayName: "Bob Johnson", size: 60)
            ProfilePhotoView(imageData: nil, displayName: "Charlie Brown", size: 40)
            ProfilePhotoView(imageData: nil, displayName: "Diana Prince", size: 30)
        }
        
        // Single name initials
        ProfilePhotoView(imageData: nil, displayName: "Superman", size: 60)
        
        // Picker with cropper enabled
        ProfilePhotoPicker(imageData: $imageData, size: 100, displayName: "Test User", enableCropper: true)
        
        // Picker with cropper disabled (for testing)
        ProfilePhotoPicker(imageData: $imageData, size: 100, displayName: "No Crop", enableCropper: false)
    }
    .padding()
}

#Preview("Image Cropper") {
    @Previewable @State var croppedData: Data? = nil
    @Previewable @State var showCropper = true
    
    // Create a test image with a colored background so we can see it
    let testImage = createTestImage()
    
    Button("Show Cropper") {
        showCropper = true
    }
    .sheet(isPresented: $showCropper) {
        ImageCropperView(
            image: testImage,
            onCrop: { cropped in
                print("Cropped image size: \(cropped.size)")
                croppedData = cropped.pngData()
                showCropper = false
            },
            onCancel: {
                print("Cancelled")
                showCropper = false
            }
        )
    }
}

#Preview("Cropper Debug - Simple") {
    // Ultra-simple test to verify the cropper shows ANYTHING
    @Previewable @State var showSheet = true
    
    Button("Show Cropper") {
        showSheet = true
    }
    .sheet(isPresented: $showSheet) {
        NavigationStack {
            ZStack {
                Color.red // Should see red if view loads
                    .ignoresSafeArea()
                
                Text("Can you see this?")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
            .navigationTitle("Debug Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showSheet = false
                    }
                }
            }
        }
    }
}

// Helper function to create a test image
private func createTestImage() -> UIImage {
    let size = CGSize(width: 300, height: 300)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    let image = renderer.image { context in
        // Draw a gradient background
        let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors as CFArray,
                                 locations: [0.0, 1.0])!
        
        context.cgContext.drawLinearGradient(gradient,
                                            start: CGPoint(x: 0, y: 0),
                                            end: CGPoint(x: size.width, y: size.height),
                                            options: [])
        
        // Draw a circle in the center
        let circleRect = CGRect(x: size.width/2 - 50,
                               y: size.height/2 - 50,
                               width: 100,
                               height: 100)
        UIColor.white.setFill()
        context.cgContext.fillEllipse(in: circleRect)
        
        // Draw some text
        let text = "TEST"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 40, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textRect = CGRect(x: (size.width - textSize.width) / 2,
                             y: (size.height - textSize.height) / 2,
                             width: textSize.width,
                             height: textSize.height)
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }
    
    return image
}

