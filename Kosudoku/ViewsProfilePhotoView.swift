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
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCropper = false
    @State private var selectedUIImage: UIImage?
    
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
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedUIImage = uiImage
                    showingCropper = true
                }
            }
        }
        .sheet(isPresented: $showingCropper) {
            if let image = selectedUIImage {
                ImageCropperView(image: image) { croppedImage in
                    if let compressed = compressImage(croppedImage, maxSizeKB: 500) {
                        imageData = compressed
                    }
                }
                .onDisappear {
                    selectedUIImage = nil
                    selectedItem = nil
                }
            }
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

/// Simple image cropper for square profile photos
struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Black background
                Color.black
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    let cropSize = min(geometry.size.width, geometry.size.height) - 80
                    
                    ZStack {
                        // Image with gestures
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        // Prevent scaling too small
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
                        
                        // Crop overlay border
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: cropSize, height: cropSize)
                            .shadow(color: .black.opacity(0.5), radius: 5)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        viewSize = geometry.size
                    }
                }
            }
            .navigationTitle("Adjust Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cropAndSave()
                    }
                }
            }
        }
    }
    
    private func cropAndSave() {
        guard let croppedImage = cropImageToCircle() else {
            // Fallback: if cropping fails, just use the original image
            onCrop(image)
            dismiss()
            return
        }
        onCrop(croppedImage)
        dismiss()
    }
    
    private func cropImageToCircle() -> UIImage? {
        let outputSize: CGFloat = 500
        
        // Create renderer for output
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        
        let croppedImage = renderer.image { context in
            // Create circular clipping path
            let circlePath = UIBezierPath(
                ovalIn: CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
            )
            circlePath.addClip()
            
            // Calculate the draw rect to account for scale and offset
            let drawSize: CGFloat = outputSize / scale
            let drawX = (outputSize - drawSize) / 2 - (offset.width / scale)
            let drawY = (outputSize - drawSize) / 2 - (offset.height / scale)
            
            let drawRect = CGRect(
                x: drawX,
                y: drawY,
                width: drawSize,
                height: drawSize
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
        
        // Picker
        ProfilePhotoPicker(imageData: $imageData, size: 100, displayName: "Test User")
    }
    .padding()
}
