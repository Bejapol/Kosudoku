//
//  ChatBannerView.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/23/26.
//

import SwiftUI

/// In-app banner that appears at the top of the screen for notifications
struct ChatBannerView: View {
    let banner: ChatBannerNotification
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var offset: CGFloat = 0
    
    private var iconName: String {
        switch banner.bannerType {
        case .gameChat: return "gamecontroller.fill"
        case .groupChat: return "person.3.fill"
        case .friendRequest: return "person.badge.plus"
        case .gameInvite: return "envelope.fill"
        }
    }
    
    private var iconGradient: AnyGradient {
        switch banner.bannerType {
        case .gameChat: return Color.orange.gradient
        case .groupChat: return Color.green.gradient
        case .friendRequest: return Color.purple.gradient
        case .gameInvite: return Color.orange.gradient
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(iconGradient)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.senderUsername)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                
                Text(banner.content)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .padding(.horizontal, 12)
        .offset(y: offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        offset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -30 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(duration: 0.3)) {
                            offset = 0
                        }
                    }
                }
        )
        .onTapGesture {
            onTap()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    VStack {
        ChatBannerView(
            banner: ChatBannerNotification(
                senderUsername: "TestUser",
                content: "Hey, nice move!",
                bannerType: .gameChat,
                chatIdentifier: "test",
                timestamp: Date()
            ),
            onTap: {},
            onDismiss: {}
        )
        Spacer()
    }
}
