//
//  StoreView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/30/26.
//

import SwiftUI
import SwiftData

struct StoreView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var cloudKitService = CloudKitService.shared
    @State private var selectedColor: PlayerColor?
    @State private var showingConfirmation = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isSaving = false
    
    private var profile: UserProfile? {
        cloudKitService.currentUserProfile
    }
    
    private var currentCustomColor: PlayerColor? {
        guard let raw = profile?.customColorRawValue else { return nil }
        return PlayerColor(rawValue: raw)
    }
    
    private let colorPrice = 6
    
    var body: some View {
        NavigationStack {
            List {
                // Quicket balance header
                Section {
                    HStack {
                        Image(systemName: "ticket.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Quickets")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(profile?.quickets ?? 0)")
                                .font(.title)
                                .bold()
                                .foregroundColor(.orange)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                // Custom Game Color product
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .font(.title2)
                                .foregroundStyle(.linearGradient(
                                    colors: PlayerColor.allCases.map { $0.color },
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Custom Game Color")
                                    .font(.headline)
                                Text("Choose the color for your cells during games")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Color selector
                        HStack(spacing: 12) {
                            ForEach(PlayerColor.allCases, id: \.rawValue) { color in
                                colorCircle(for: color)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        
                        // Purchase / status
                        if profile?.hasCustomColor == true {
                            // Already purchased — show currently active color
                            if let current = currentCustomColor {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                    Text("Purchased — Active: \(colorName(current))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let selected = selectedColor, selected != currentCustomColor {
                                Button {
                                    changeColor(to: selected)
                                } label: {
                                    HStack {
                                        Text("Change to \(colorName(selected))")
                                        Spacer()
                                        Text("Free")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .disabled(isSaving)
                            }
                        } else {
                            // Not purchased
                            Button {
                                if selectedColor != nil {
                                    showingConfirmation = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "ticket.fill")
                                        .foregroundColor(.orange)
                                    Text("Purchase for \(colorPrice) Quickets")
                                    Spacer()
                                    if selectedColor == nil {
                                        Text("Select a color")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .disabled(selectedColor == nil || (profile?.quickets ?? 0) < colorPrice || isSaving)
                            
                            if (profile?.quickets ?? 0) < colorPrice {
                                Text("You need \(colorPrice - (profile?.quickets ?? 0)) more quickets")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Products")
                }
                
                // How to earn quickets
                Section {
                    Label("Win a multiplayer game to earn 1 quicket", systemImage: "trophy.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Earning Quickets")
                }
            }
            .navigationTitle("Store")
            .confirmationDialog(
                "Purchase Custom Color",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Buy for \(colorPrice) Quickets") {
                    purchaseColor()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let color = selectedColor {
                    Text("Spend \(colorPrice) quickets to set your game color to \(colorName(color))? You can change the color for free after purchase.")
                }
            }
            .alert("Purchased!", isPresented: $showingSuccess) {
                Button("OK") { }
            } message: {
                Text("Your custom game color is now active. It will be used in your next game.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Something went wrong")
            }
        }
    }
    
    @ViewBuilder
    private func colorCircle(for color: PlayerColor) -> some View {
        let isSelected = selectedColor == color
        let isCurrentCustom = currentCustomColor == color
        
        Button {
            selectedColor = color
        } label: {
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 44, height: 44)
                
                if isCurrentCustom {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
                    .frame(width: 50, height: 50)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func colorName(_ color: PlayerColor) -> String {
        switch color {
        case .coral: return "Coral"
        case .teal: return "Teal"
        case .amber: return "Amber"
        case .violet: return "Violet"
        case .lime: return "Lime"
        case .rose: return "Rose"
        }
    }
    
    private func purchaseColor() {
        guard let profile = profile,
              let color = selectedColor,
              profile.quickets >= colorPrice else { return }
        
        isSaving = true
        profile.quickets -= colorPrice
        profile.customColorRawValue = color.rawValue
        try? modelContext.save()
        
        Task {
            do {
                try await cloudKitService.saveUserProfile(profile)
                await MainActor.run {
                    isSaving = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    // Revert on failure
                    profile.quickets += colorPrice
                    profile.customColorRawValue = nil
                    try? modelContext.save()
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func changeColor(to color: PlayerColor) {
        guard let profile = profile else { return }
        
        isSaving = true
        profile.customColorRawValue = color.rawValue
        try? modelContext.save()
        
        Task {
            do {
                try await cloudKitService.saveUserProfile(profile)
                await MainActor.run {
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    StoreView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
