//
//  ContactRowView.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 21, 2025.
//  Purpose: Reusable contact row component displaying user info,
//           profile picture, and online status (PR #8)
//

import SwiftUI

struct ContactRowView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            profilePicture
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Online Status Indicator
            if user.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var profilePicture: some View {
        if let photoURL = user.photoURL, !photoURL.isEmpty {
            // Load profile picture from URL
            AsyncImage(url: URL(string: photoURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure, .empty:
                    placeholderImage
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }
    
    private var placeholderImage: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 50, height: 50)
            .overlay(
                Text(user.displayName.prefix(1).uppercased())
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        ContactRowView(
            user: User(
                id: "1",
                email: "jane@example.com",
                displayName: "Jane Doe",
                photoURL: nil,
                isOnline: true,
                lastSeen: Date(),
                createdAt: Date()
            )
        )
        .padding(.horizontal)
        
        Divider()
        
        ContactRowView(
            user: User(
                id: "2",
                email: "john@example.com",
                displayName: "John Smith",
                photoURL: nil,
                isOnline: false,
                lastSeen: Date(),
                createdAt: Date()
            )
        )
        .padding(.horizontal)
    }
}

