//
//  ToastNotificationView.swift
//  messAI
//
//  Created for PR#17.1: In-App Toast Notifications
//

import SwiftUI

/// Toast notification view that slides from top
/// Displays sender info, message preview, and handles user interactions
struct ToastNotificationView: View {
    
    // MARK: - Properties
    
    @ObservedObject var manager: ToastNotificationManager
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if manager.isShowingToast, let toast = manager.currentToast {
                ToastCard(toast: toast)
                    .padding(.horizontal, 16)
                    .padding(.top, 8) // Below status bar
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        manager.handleToastTap(conversationId: toast.conversationId)
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                // Swipe up to dismiss
                                if value.translation.height < -50 {
                                    manager.dismissToast()
                                }
                            }
                    )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.isShowingToast)
    }
}

// MARK: - Toast Card

private struct ToastCard: View {
    let toast: ToastMessage
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture or Initials
            ProfileImage(toast: toast)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Sender Name
                Text(toast.senderName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Message Preview
                Text(toast.displayText)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Profile Image

private struct ProfileImage: View {
    let toast: ToastMessage
    
    var body: some View {
        if let photoURL = toast.senderPhotoURL, let url = URL(string: photoURL) {
            // Profile picture from URL
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                InitialsCircle(initials: toast.senderInitials)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            // Fallback to initials
            InitialsCircle(initials: toast.senderInitials)
        }
    }
}

// MARK: - Initials Circle

private struct InitialsCircle: View {
    let initials: String
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 44, height: 44)
            .overlay(
                Text(initials)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Previews

#Preview("Single Toast") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        ToastNotificationView(manager: {
            let manager = ToastNotificationManager.shared
            manager.currentToast = .sample
            manager.isShowingToast = true
            return manager
        }())
    }
}

#Preview("Image Toast") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        ToastNotificationView(manager: {
            let manager = ToastNotificationManager.shared
            manager.currentToast = .sampleImage
            manager.isShowingToast = true
            return manager
        }())
    }
}

#Preview("Short Message") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        ToastNotificationView(manager: {
            let manager = ToastNotificationManager.shared
            manager.currentToast = .sampleShort
            manager.isShowingToast = true
            return manager
        }())
    }
}

#Preview("No Toast") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        ToastNotificationView(manager: ToastNotificationManager.shared)
    }
}

