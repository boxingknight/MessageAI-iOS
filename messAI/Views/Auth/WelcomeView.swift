import SwiftUI

struct WelcomeView: View {
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Logo
            Image(systemName: "message.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            // Title
            Text("MessageAI")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Subtitle
            Text("Fast, reliable, and secure messaging")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 16) {
                // Sign In button
                Button {
                    navigationPath.append(AuthRoute.login)
                } label: {
                    Text("Sign In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                // Sign Up button
                Button {
                    navigationPath.append(AuthRoute.signup)
                } label: {
                    Text("Sign Up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WelcomeView(navigationPath: .constant(NavigationPath()))
    }
}

