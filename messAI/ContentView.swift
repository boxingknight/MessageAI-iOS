//
//  ContentView.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        // Note: ContentView is only shown when authenticated with valid currentUser
        // (checked in messAIApp.swift)
        if let currentUser = authViewModel.currentUser {
            ChatListView(
                viewModel: ChatListViewModel(
                    chatService: ChatService(),
                    localDataManager: LocalDataManager.shared,
                    currentUserId: currentUser.id
                )
            )
        } else {
            // Loading state (brief moment while fetching user)
            VStack {
                ProgressView()
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
        }
    }
    
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
