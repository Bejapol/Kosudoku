//
//  ProfilePhotoView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/9/26.
//

import SwiftUI
import PhotosUI

/// Reusable profile photo component that displays user avatars
struct ProfilePhotoView: View {
    let imageData: Data?
    let displayName: String
    let size: CGFloat
    
    init(imageData: Data?, displayName: String, size: CGFloat = 40) {
        self.imageData = imageData
        self.displayName = displayName
        self.size = size
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
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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

/// Simple image cropper for square profile photos
struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let cropSize = min(geometry.size.width, geometry.size.height) - 80
                
                ZStack {
                    // Black background
                    Color.black
                        .ignoresSafeArea()
                    
                    // Image with gestures
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value
                                    scale = max(newScale, 0.5)
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
                    
                    // Crop overlay - circular guideline
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: cropSize, height: cropSize)
                        .allowsHitTesting(false)
                    
                    // Corner guides to show it's a square crop area
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .frame(width: cropSize, height: cropSize)
                        .allowsHitTesting(false)
                }
                .onAppear {
                    print("🖼️ ImageCropperView appeared")
                    print("   Image size: \(image.size)")
                    print("   Geometry size: \(geometry.size)")
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
                        print("❌ Cropping cancelled")
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
        .onAppear {
            print("🎨 ImageCropperView NavigationStack appeared")
        }
    }
    
    private func cropAndSave() {
        print("🔄 Cropping image...")
        guard let croppedImage = cropImageToCircle() else {
            print("⚠️ Cropping failed, using original image")
            // Fallback: if cropping fails, just use the original image
            onCrop(image)
            return
        }
        print("✅ Image cropped successfully")
        onCrop(croppedImage)
    }
    
    private func cropImageToCircle() -> UIImage? {
        let outputSize: CGFloat = 500
        
        // Create a graphics context
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Use 1x scale for consistent output
        format.opaque = false // Support transparency
        
        // Create renderer for output
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize),
            format: format
        )
        
        let croppedImage = renderer.image { context in
            // Create circular clipping path
            let circlePath = UIBezierPath(
                ovalIn: CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
            )
            circlePath.addClip()
            
            // Calculate image aspect ratio
            let imageAspect = image.size.width / image.size.height
            var drawSize: CGSize
            
            if imageAspect > 1 {
                // Landscape: fit to height
                let height = outputSize / scale
                let width = height * imageAspect
                drawSize = CGSize(width: width, height: height)
            } else {
                // Portrait or square: fit to width
                let width = outputSize / scale
                let height = width / imageAspect
                drawSize = CGSize(width: width, height: height)
            }
            
            // Center the image and apply offset
            let drawX = (outputSize - drawSize.width) / 2 - (offset.width / scale)
            let drawY = (outputSize - drawSize.height) / 2 - (offset.height / scale)
            
            let drawRect = CGRect(
                x: drawX,
                y: drawY,
                width: drawSize.width,
                height: drawSize.height
            )
            
            // Draw the image
            image.draw(in: drawRect)
        }
        
        return croppedImage
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

