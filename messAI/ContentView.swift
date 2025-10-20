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
        VStack(spacing: 20) {
            Text("Auth Testing")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Display auth status
            if authViewModel.isAuthenticated {
                Text("✅ Authenticated")
                    .foregroundColor(.green)
                    .font(.title2)
                
                if let user = authViewModel.currentUser {
                    VStack(spacing: 8) {
                        Text("User: \(user.displayName)")
                            .font(.headline)
                        Text("Email: \(user.email)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button("Sign Out") {
                    Task {
                        await authViewModel.signOut()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Text("❌ Not Authenticated")
                    .foregroundColor(.red)
                    .font(.title2)
                
                VStack(spacing: 12) {
                    Button("Test Sign Up") {
                        Task {
                            await authViewModel.signUp(
                                email: "test@example.com",
                                password: "password123",
                                displayName: "Test User"
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test Sign In") {
                        Task {
                            await authViewModel.signIn(
                                email: "test@example.com",
                                password: "password123"
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Display errors
            if let error = authViewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
            }
            
            // Loading indicator
            if authViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
