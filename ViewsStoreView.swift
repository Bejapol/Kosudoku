//
//  StoreView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/30/26.
//

import SwiftUI
import SwiftData
import StoreKit

struct StoreView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var cloudKitService = CloudKitService.shared
    @State private var storeManager = StoreManager.shared
    @State private var showingPurchaseSuccess = false
    @State private var showingItemSuccess = false
    @State private var itemSuccessMessage = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isSaving = false
    
    // Color selection
    @State private var selectedColor: PlayerColor?
    @State private var showingColorConfirmation = false
    
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
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Quicket Balance
                    quicketBalanceHeader
                        .padding(.horizontal)
                        .padding(.top, 12)
                    
                    // MARK: - Cosmetics
                    storeSection(title: "Cosmetics", icon: "paintbrush.fill") {
                        // Player Colors
                        playerColorsSection
                        
                        sectionDivider
                        
                        // Cell Themes
                        cosmeticSection(
                            title: "Cell Themes",
                            icon: "square.grid.3x3",
                            description: "Change the look of cell highlights",
                            items: CellTheme.allCases,
                            equippedRaw: profile?.equippedCellTheme,
                            ownedSet: profile?.ownedCellThemes,
                            defaultCase: .classic,
                            owns: { profile?.ownsCellTheme($0) ?? ($0 == .classic) },
                            onPurchase: { theme in
                                await purchaseCosmeticItem(cost: theme.price) { p in
                                    p.ownedCellThemes = UserProfile.addToOwnedSet(p.ownedCellThemes, rawValue: theme.rawValue)
                                    p.equippedCellTheme = theme.rawValue
                                }
                            },
                            onEquip: { theme in
                                equipItem { $0.equippedCellTheme = theme.rawValue }
                            }
                        )
                        
                        sectionDivider
                        
                        // Board Skins
                        cosmeticSection(
                            title: "Board Skins",
                            icon: "rectangle.grid.3x2",
                            description: "Change the grid background and lines",
                            items: BoardSkin.allCases,
                            equippedRaw: profile?.equippedBoardSkin,
                            ownedSet: profile?.ownedBoardSkins,
                            defaultCase: .classic,
                            owns: { profile?.ownsBoardSkin($0) ?? ($0 == .classic) },
                            onPurchase: { skin in
                                await purchaseCosmeticItem(cost: skin.price) { p in
                                    p.ownedBoardSkins = UserProfile.addToOwnedSet(p.ownedBoardSkins, rawValue: skin.rawValue)
                                    p.equippedBoardSkin = skin.rawValue
                                }
                            },
                            onEquip: { skin in
                                equipItem { $0.equippedBoardSkin = skin.rawValue }
                            }
                        )
                        
                        sectionDivider
                        
                        // Victory Animations
                        cosmeticSection(
                            title: "Victory Animations",
                            icon: "sparkles",
                            description: "Custom win celebration effects",
                            items: VictoryAnimation.allCases,
                            equippedRaw: profile?.equippedVictoryAnimation,
                            ownedSet: profile?.ownedVictoryAnimations,
                            defaultCase: .confetti,
                            owns: { profile?.ownsVictoryAnimation($0) ?? ($0 == .confetti) },
                            onPurchase: { anim in
                                await purchaseCosmeticItem(cost: anim.price) { p in
                                    p.ownedVictoryAnimations = UserProfile.addToOwnedSet(p.ownedVictoryAnimations, rawValue: anim.rawValue)
                                    p.equippedVictoryAnimation = anim.rawValue
                                }
                            },
                            onEquip: { anim in
                                equipItem { $0.equippedVictoryAnimation = anim.rawValue }
                            }
                        )
                        
                        sectionDivider
                        
                        // Profile Frames
                        cosmeticSection(
                            title: "Profile Frames",
                            icon: "circle.circle",
                            description: "Decorative borders for your profile photo",
                            items: ProfileFrame.allCases,
                            equippedRaw: profile?.equippedProfileFrame,
                            ownedSet: profile?.ownedProfileFrames,
                            defaultCase: .none,
                            owns: { profile?.ownsProfileFrame($0) ?? ($0 == .none) },
                            onPurchase: { frame in
                                await purchaseCosmeticItem(cost: frame.price) { p in
                                    p.ownedProfileFrames = UserProfile.addToOwnedSet(p.ownedProfileFrames, rawValue: frame.rawValue)
                                    p.equippedProfileFrame = frame.rawValue
                                }
                            },
                            onEquip: { frame in
                                equipItem { $0.equippedProfileFrame = frame.rawValue }
                            }
                        )
                        
                        sectionDivider
                        
                        // Title Badges
                        cosmeticSection(
                            title: "Title Badges",
                            icon: "tag.fill",
                            description: "Show a title next to your name",
                            items: TitleBadge.allCases,
                            equippedRaw: profile?.equippedTitleBadge,
                            ownedSet: profile?.ownedTitleBadges,
                            defaultCase: .none,
                            owns: { profile?.ownsTitleBadge($0) ?? ($0 == .none) },
                            onPurchase: { badge in
                                await purchaseCosmeticItem(cost: badge.price) { p in
                                    p.ownedTitleBadges = UserProfile.addToOwnedSet(p.ownedTitleBadges, rawValue: badge.rawValue)
                                    p.equippedTitleBadge = badge.rawValue
                                }
                            },
                            onEquip: { badge in
                                equipItem { $0.equippedTitleBadge = badge.rawValue }
                            }
                        )
                        
                        sectionDivider
                        
                        // Game Invite Themes
                        cosmeticSection(
                            title: "Game Invite Themes",
                            icon: "envelope.fill",
                            description: "Themed invitation cards when challenging friends",
                            items: GameInviteTheme.allCases,
                            equippedRaw: profile?.equippedGameInviteTheme,
                            ownedSet: profile?.ownedGameInviteThemes,
                            defaultCase: .classic,
                            owns: { profile?.ownsGameInviteTheme($0) ?? ($0 == .classic) },
                            onPurchase: { theme in
                                await purchaseCosmeticItem(cost: theme.price) { p in
                                    p.ownedGameInviteThemes = UserProfile.addToOwnedSet(p.ownedGameInviteThemes, rawValue: theme.rawValue)
                                    p.equippedGameInviteTheme = theme.rawValue
                                }
                            },
                            onEquip: { theme in
                                equipItem { $0.equippedGameInviteTheme = theme.rawValue }
                            }
                        )
                        
                        sectionDivider
                        
                        // Number Fonts
                        cosmeticSection(
                            title: "Number Fonts",
                            icon: "textformat",
                            description: "Change the digit style on the board",
                            items: NumberFont.allCases,
                            equippedRaw: profile?.equippedNumberFont,
                            ownedSet: profile?.ownedNumberFonts,
                            defaultCase: .classic,
                            owns: { profile?.ownsNumberFont($0) ?? ($0 == .classic) },
                            onPurchase: { font in
                                await purchaseCosmeticItem(cost: font.price) { p in
                                    p.ownedNumberFonts = UserProfile.addToOwnedSet(p.ownedNumberFonts, rawValue: font.rawValue)
                                    p.equippedNumberFont = font.rawValue
                                }
                            },
                            onEquip: { font in
                                equipItem { $0.equippedNumberFont = font.rawValue }
                            }
                        )
                        
                        sectionDivider
                        
                        // Sound Packs
                        cosmeticSection(
                            title: "Sound Packs",
                            icon: "speaker.wave.2.fill",
                            description: "Change game sound effects",
                            items: SoundPack.allCases,
                            equippedRaw: profile?.equippedSoundPack,
                            ownedSet: profile?.ownedSoundPacks,
                            defaultCase: .classic,
                            owns: { profile?.ownsSoundPack($0) ?? ($0 == .classic) },
                            onPurchase: { pack in
                                await purchaseCosmeticItem(cost: pack.price) { p in
                                    p.ownedSoundPacks = UserProfile.addToOwnedSet(p.ownedSoundPacks, rawValue: pack.rawValue)
                                    p.equippedSoundPack = pack.rawValue
                                }
                            },
                            onEquip: { pack in
                                equipItem { $0.equippedSoundPack = pack.rawValue }
                            }
                        )
                        
                        sectionDivider
                        
                        // Chat Bubble Styles
                        cosmeticSection(
                            title: "Chat Bubble Styles",
                            icon: "bubble.left.fill",
                            description: "Change the look of chat messages",
                            items: ChatBubbleStyle.allCases,
                            equippedRaw: profile?.equippedChatBubbleStyle,
                            ownedSet: profile?.ownedChatBubbleStyles,
                            defaultCase: .classic,
                            owns: { profile?.ownsChatBubbleStyle($0) ?? ($0 == .classic) },
                            onPurchase: { style in
                                await purchaseCosmeticItem(cost: style.price) { p in
                                    p.ownedChatBubbleStyles = UserProfile.addToOwnedSet(p.ownedChatBubbleStyles, rawValue: style.rawValue)
                                    p.equippedChatBubbleStyle = style.rawValue
                                }
                            },
                            onEquip: { style in
                                equipItem { $0.equippedChatBubbleStyle = style.rawValue }
                            }
                        )
                        
                        sectionDivider
                        
                        // Profile Banners
                        cosmeticSection(
                            title: "Profile Banners",
                            icon: "rectangle.fill",
                            description: "Decorative gradient banners for your profile",
                            items: ProfileBanner.allCases,
                            equippedRaw: profile?.equippedProfileBanner,
                            ownedSet: profile?.ownedProfileBanners,
                            defaultCase: .none,
                            owns: { profile?.ownsProfileBanner($0) ?? ($0 == .none) },
                            onPurchase: { banner in
                                await purchaseCosmeticItem(cost: banner.price) { p in
                                    p.ownedProfileBanners = UserProfile.addToOwnedSet(p.ownedProfileBanners, rawValue: banner.rawValue)
                                    p.equippedProfileBanner = banner.rawValue
                                }
                            },
                            onEquip: { banner in
                                equipItem { $0.equippedProfileBanner = banner.rawValue }
                            }
                        )
                    }
                    
                    // MARK: - Gameplay Boosts
                    storeSection(title: "Gameplay Boosts", icon: "bolt.fill") {
                        consumableRow(
                            boost: .hintToken,
                            count: profile?.hintTokens ?? 0,
                            onPurchase: { await purchaseConsumable(cost: 3) { $0.hintTokens += 1 } }
                        )
                        sectionDivider
                        consumableRow(
                            boost: .undoShield,
                            count: profile?.undoShields ?? 0,
                            onPurchase: { await purchaseConsumable(cost: 3) { $0.undoShields += 1 } }
                        )
                        sectionDivider
                        consumableRow(
                            boost: .streakSaver,
                            count: profile?.streakSavers ?? 0,
                            onPurchase: { await purchaseConsumable(cost: 5) { $0.streakSavers += 1 } }
                        )
                        sectionDivider
                        consumableRow(
                            boost: .loginStreakSaver,
                            count: profile?.loginStreakSavers ?? 0,
                            onPurchase: { await purchaseConsumable(cost: 5) { $0.loginStreakSavers += 1 } }
                        )
                        sectionDivider
                        doubleXPRow
                    }
                    
                    // MARK: - Social
                    storeSection(title: "Social", icon: "person.2.fill") {
                        unlockableRow(
                            name: "Classic Emote Pack",
                            icon: "face.smiling",
                            description: "6 quick-reaction emotes for game chat & lobby",
                            isUnlocked: profile?.hasEmotePack ?? false,
                            price: 8,
                            onPurchase: { await purchaseConsumable(cost: 8) { $0.hasEmotePack = true } }
                        )
                        sectionDivider
                        unlockableRow(
                            name: "Celebration Pack",
                            icon: "party.popper",
                            description: "6 celebration emotes: 🎉😍🏆🚀✨🤡",
                            isUnlocked: profile?.hasCelebrationPack ?? false,
                            price: 8,
                            onPurchase: {
                                await purchaseConsumable(cost: 8) { p in
                                    let current = p.ownedEmotePacks ?? ""
                                    if current.isEmpty {
                                        p.ownedEmotePacks = "celebration"
                                    } else if !current.contains("celebration") {
                                        p.ownedEmotePacks = current + ",celebration"
                                    }
                                }
                            }
                        )
                        sectionDivider
                        unlockableRow(
                            name: "Animals Pack",
                            icon: "pawprint.fill",
                            description: "6 animal emotes: 🐱🐶🙈🐧🦄🐉",
                            isUnlocked: profile?.hasAnimalsPack ?? false,
                            price: 8,
                            onPurchase: {
                                await purchaseConsumable(cost: 8) { p in
                                    let current = p.ownedEmotePacks ?? ""
                                    if current.isEmpty {
                                        p.ownedEmotePacks = "animals"
                                    } else if !current.contains("animals") {
                                        p.ownedEmotePacks = current + ",animals"
                                    }
                                }
                            }
                        )
                    }
                    
                    // MARK: - Progression
                    storeSection(title: "Progression", icon: "chart.bar.fill") {
                        unlockableRow(
                            name: "Extended Stats",
                            icon: "chart.line.uptrend.xyaxis",
                            description: "Detailed performance analytics and history",
                            isUnlocked: profile?.hasExtendedStats ?? false,
                            price: 12,
                            onPurchase: { await purchaseConsumable(cost: 12) { $0.hasExtendedStats = true } }
                        )
                    }
                    
                    // MARK: - How to Earn
                    storeSection(title: "Earning Quickets", icon: "info.circle") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Win a multiplayer game to earn 1 quicket", systemImage: "trophy.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Label("Purchase quickets below", systemImage: "cart.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // MARK: - Buy Quickets (IAP)
                    storeSection(title: "Buy Quickets", icon: "cart.fill") {
                        buyQuicketsSection
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Store")
            .confirmationDialog(
                "Purchase Custom Color",
                isPresented: $showingColorConfirmation,
                titleVisibility: .visible
            ) {
                Button("Buy for \(colorPrice) Quickets") {
                    purchaseColor()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let color = selectedColor {
                    Text("Spend \(colorPrice) quickets to set your game color to \(color.displayName)? You can change the color for free after purchase.")
                }
            }
            .alert("Success!", isPresented: $showingItemSuccess) {
                Button("OK") { }
            } message: {
                Text(itemSuccessMessage)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Something went wrong")
            }
            .alert("Quickets Added!", isPresented: $showingPurchaseSuccess) {
                Button("OK") { }
            } message: {
                Text("5 quickets have been added to your balance.")
            }
        }
    }
    
    // MARK: - Layout Components
    
    private var quicketBalanceHeader: some View {
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func storeSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                content()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private var sectionDivider: some View {
        Divider().padding(.vertical, 8)
    }
    
    // MARK: - Buy Quickets
    
    private var buyQuicketsSection: some View {
        Group {
            if let product = storeManager.quicketsProduct {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.displayName)
                            .font(.headline)
                        Text(product.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        Task {
                            let success = await storeManager.purchaseQuickets()
                            if success {
                                try? modelContext.save()
                                showingPurchaseSuccess = true
                            }
                        }
                    } label: {
                        Text(product.displayPrice)
                            .font(.subheadline)
                            .bold()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(storeManager.isPurchasing)
                }
            } else if storeManager.hasAttemptedLoad {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unable to load store products.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await storeManager.loadProducts() }
                    }
                    .font(.subheadline)
                }
            } else {
                HStack {
                    ProgressView()
                    Text("Loading store...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = storeManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Player Colors
    
    private var playerColorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "paintpalette.fill")
                    .font(.title3)
                    .foregroundStyle(.linearGradient(
                        colors: PlayerColor.allCases.map { $0.color },
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Game Colors")
                        .font(.subheadline).bold()
                    Text("Choose the color for your cells")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Default colors
            Text("Default").font(.caption).foregroundColor(.secondary)
            HStack(spacing: 10) {
                ForEach(PlayerColor.defaultColors, id: \.rawValue) { color in
                    colorCircle(for: color)
                }
            }
            
            // Premium colors
            Text("Premium").font(.caption).foregroundColor(.secondary)
            HStack(spacing: 10) {
                ForEach(PlayerColor.premiumColors, id: \.rawValue) { color in
                    colorCircle(for: color, isPremium: true)
                }
            }
            
            // Purchase / equip buttons
            if profile?.hasCustomColor == true {
                if let current = currentCustomColor {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Active: \(current.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if let selected = selectedColor, selected != currentCustomColor {
                    if profile?.ownsPlayerColor(selected) ?? false || PlayerColor.defaultColors.contains(selected) {
                        Button {
                            changeColor(to: selected)
                        } label: {
                            Text("Switch to \(selected.displayName)")
                                .font(.subheadline)
                        }
                        .disabled(isSaving)
                    } else {
                        // Premium color not yet purchased
                        Button {
                            showingColorConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "ticket.fill")
                                    .foregroundColor(.orange)
                                Text("Buy \(selected.displayName) for \(colorPrice) Quickets")
                                    .font(.subheadline)
                            }
                        }
                        .disabled((profile?.quickets ?? 0) < colorPrice || isSaving)
                    }
                }
            } else {
                Button {
                    if selectedColor != nil {
                        showingColorConfirmation = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "ticket.fill")
                            .foregroundColor(.orange)
                        Text("Purchase for \(colorPrice) Quickets")
                            .font(.subheadline)
                        if selectedColor == nil {
                            Text("(select a color)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(selectedColor == nil || (profile?.quickets ?? 0) < colorPrice || isSaving)
            }
        }
    }
    
    // MARK: - Generic Cosmetic Section
    
    private func cosmeticSection<T: RawRepresentable & CaseIterable & Hashable>(
        title: String,
        icon: String,
        description: String,
        items: [T],
        equippedRaw: String?,
        ownedSet: String?,
        defaultCase: T,
        owns: @escaping (T) -> Bool,
        onPurchase: @escaping (T) async -> Void,
        onEquip: @escaping (T) -> Void
    ) -> some View where T.RawValue == String, T: StoreDisplayable {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).bold()
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items, id: \.rawValue) { item in
                        let isOwned = owns(item)
                        let isEquipped = (equippedRaw == item.rawValue) || (equippedRaw == nil && item.rawValue == defaultCase.rawValue)
                        
                        Button {
                            if isEquipped {
                                // Already equipped, do nothing
                            } else if isOwned {
                                onEquip(item)
                            } else {
                                Task { await onPurchase(item) }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: item.storeIcon)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(isEquipped ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isEquipped ? Color.accentColor : Color.clear, lineWidth: 2)
                                    )
                                
                                Text(item.storeDisplayName)
                                    .font(.caption2)
                                    .lineLimit(1)
                                
                                if isEquipped {
                                    Text("Active")
                                        .font(.caption2)
                                        .foregroundColor(.accentColor)
                                } else if isOwned {
                                    Text("Owned")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                } else if item.storePrice > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "ticket.fill")
                                            .font(.system(size: 8))
                                        Text("\(item.storePrice)")
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                } else {
                                    Text("Free")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(.plain)
                        .disabled(isEquipped || isSaving)
                    }
                }
            }
        }
    }
    
    // MARK: - Consumable Row
    
    private func consumableRow(boost: ConsumableBoost, count: Int, onPurchase: @escaping () async -> Void) -> some View {
        HStack {
            Image(systemName: boost.icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(boost.displayName)
                        .font(.subheadline).bold()
                    if count > 0 {
                        Text("x\(count)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                Text(boost.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                Task { await onPurchase() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "ticket.fill")
                        .font(.caption)
                    Text("\(boost.price)")
                        .font(.subheadline).bold()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .disabled((profile?.quickets ?? 0) < boost.price || isSaving)
        }
    }
    
    // MARK: - Double XP Row
    
    private var doubleXPRow: some View {
        HStack {
            Image(systemName: ConsumableBoost.doubleXPToken.icon)
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(ConsumableBoost.doubleXPToken.displayName)
                        .font(.subheadline).bold()
                    if (profile?.doubleXPTokens ?? 0) > 0 {
                        Text("x\(profile?.doubleXPTokens ?? 0)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                Text(ConsumableBoost.doubleXPToken.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if profile?.isDoubleXPActive == true,
                   let until = profile?.doubleXPActiveUntil {
                    let remaining = Int(until.timeIntervalSinceNow / 60) + 1
                    Text("Active: \(remaining)m remaining")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .bold()
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Button {
                    Task { await purchaseConsumable(cost: 8) { $0.doubleXPTokens += 1 } }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ticket.fill")
                            .font(.caption)
                        Text("\(ConsumableBoost.doubleXPToken.price)")
                            .font(.subheadline).bold()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled((profile?.quickets ?? 0) < ConsumableBoost.doubleXPToken.price || isSaving)
                
                if (profile?.doubleXPTokens ?? 0) > 0 && profile?.isDoubleXPActive != true {
                    Button {
                        activateDoubleXP()
                    } label: {
                        Text("Activate")
                            .font(.caption).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
    
    // MARK: - Unlockable Row
    
    private func unlockableRow(name: String, icon: String, description: String, isUnlocked: Bool, price: Int, onPurchase: @escaping () async -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isUnlocked ? .green : .accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline).bold()
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button {
                    Task { await onPurchase() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ticket.fill")
                            .font(.caption)
                        Text("\(price)")
                            .font(.subheadline).bold()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled((profile?.quickets ?? 0) < price || isSaving)
            }
        }
    }
    
    // MARK: - Color Circle
    
    @ViewBuilder
    private func colorCircle(for color: PlayerColor, isPremium: Bool = false) -> some View {
        let isSelected = selectedColor == color
        let isCurrentCustom = currentCustomColor == color
        let isOwned = profile?.ownsPlayerColor(color) ?? PlayerColor.defaultColors.contains(color)
        
        Button {
            selectedColor = color
        } label: {
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 40, height: 40)
                
                if isCurrentCustom {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                if isPremium && !isOwned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .offset(x: 12, y: 12)
                }
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                    .frame(width: 46, height: 46)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Purchase Helpers
    
    private func purchaseCosmeticItem(cost: Int, apply: @escaping (UserProfile) -> Void) async {
        isSaving = true
        let success = await storeManager.purchaseWithQuickets(cost: cost, apply: apply)
        isSaving = false
        if success {
            try? modelContext.save()
            itemSuccessMessage = "Item purchased and equipped!"
            showingItemSuccess = true
        } else if let error = storeManager.errorMessage {
            errorMessage = error
            showingError = true
        }
    }
    
    private func purchaseConsumable(cost: Int, apply: @escaping (UserProfile) -> Void) async {
        isSaving = true
        let success = await storeManager.purchaseWithQuickets(cost: cost, apply: apply)
        isSaving = false
        if success {
            try? modelContext.save()
        } else if let error = storeManager.errorMessage {
            errorMessage = error
            showingError = true
        }
    }
    
    private func activateDoubleXP() {
        guard let profile, profile.doubleXPTokens > 0 else { return }
        isSaving = true
        profile.doubleXPTokens -= 1
        profile.doubleXPActiveUntil = Date().addingTimeInterval(15 * 60)
        try? modelContext.save()
        Task {
            try? await cloudKitService.saveUserProfile(profile)
            isSaving = false
            itemSuccessMessage = "Double XP activated for 15 minutes!"
            showingItemSuccess = true
        }
    }
    
    private func equipItem(apply: @escaping (UserProfile) -> Void) {
        guard let profile else { return }
        isSaving = true
        apply(profile)
        try? modelContext.save()
        Task {
            try? await cloudKitService.saveUserProfile(profile)
            isSaving = false
        }
    }
    
    private func purchaseColor() {
        guard let profile = profile,
              let color = selectedColor,
              profile.quickets >= colorPrice else { return }
        
        isSaving = true
        
        // For premium colors, also add to ownedPlayerColors
        if PlayerColor.premiumColors.contains(color) {
            profile.ownedPlayerColors = UserProfile.addToOwnedSet(profile.ownedPlayerColors, rawValue: String(color.rawValue))
        }
        
        profile.quickets -= colorPrice
        profile.customColorRawValue = color.rawValue
        try? modelContext.save()
        
        Task {
            do {
                try await cloudKitService.saveUserProfile(profile)
                isSaving = false
                itemSuccessMessage = "Custom game color set to \(color.displayName)!"
                showingItemSuccess = true
            } catch {
                // Revert
                profile.quickets += colorPrice
                profile.customColorRawValue = nil
                try? modelContext.save()
                isSaving = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func changeColor(to color: PlayerColor) {
        guard let profile = profile else { return }
        isSaving = true
        profile.customColorRawValue = color.rawValue
        try? modelContext.save()
        Task {
            try? await cloudKitService.saveUserProfile(profile)
            isSaving = false
        }
    }
}

// MARK: - Protocol for generic cosmetic display

protocol StoreDisplayable {
    var storeDisplayName: String { get }
    var storePrice: Int { get }
    var storeIcon: String { get }
}

extension CellTheme: StoreDisplayable {
    var storeDisplayName: String { displayName }
    var storePrice: Int { price }
    var storeIcon: String { icon }
}

extension BoardSkin: StoreDisplayable {
    var storeDisplayName: String { displayName }
    var storePrice: Int { price }
    var storeIcon: String { icon }
}

extension VictoryAnimation: StoreDisplayable {
    var storeDisplayName: String { displayName }
    var storePrice: Int { price }
    var storeIcon: String { icon }
}

extension ProfileFrame: StoreDisplayable {
    var storeDisplayName: String { displayName }
    var storePrice: Int { price }
    var storeIcon: String { icon }
}

extension TitleBadge: StoreDisplayable {
    var storeDisplayName: String { displayName }
    var storePrice: Int { price }
    var storeIcon: String { icon }
}

extension GameInviteTheme: StoreDisplayable {
    var storeDisplayName: String { displayName }
    var storePrice: Int { price }
    var storeIcon: String { icon }
}

#Preview {
    StoreView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
