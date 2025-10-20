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
        NavigationStack {
            VStack(spacing: 20) {
                Text("Main App")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("You're logged in as:")
                    .foregroundColor(.secondary)
                
                if let user = authViewModel.currentUser {
                    Text(user.displayName)
                        .font(.title2)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button("Sign Out") {
                    Task {
                        await authViewModel.signOut()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .navigationTitle("MessageAI")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
