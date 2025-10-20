import SwiftUI

// MARK: - Auth Route Enum

enum AuthRoute: Hashable {
    case login
    case signup
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            WelcomeView(navigationPath: $navigationPath)
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .login:
                        LoginView(navigationPath: $navigationPath)
                    case .signup:
                        SignUpView(navigationPath: $navigationPath)
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}

