import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            BrowseView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Browse")
                }
                .tag(0)

            MapListingsView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
                }
                .tag(1)

            Group {
                if authService.isSignedIn {
                    SellView(selectedTab: $selectedTab)
                } else {
                    SignInPromptView(feature: "sell items")
                }
            }
            .tabItem {
                Image(systemName: "plus.circle.fill")
                Text("Sell")
            }
            .tag(2)

            Group {
                if authService.isSignedIn {
                    MessagesView()
                } else {
                    SignInPromptView(feature: "view messages")
                }
            }
            .tabItem {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("Chats")
            }
            .tag(3)

            Group {
                if authService.isSignedIn {
                    ProfileView()
                } else {
                    SignInPromptView(feature: "access your profile")
                }
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Me")
            }
            .tag(4)
        }
        .tint(Color(red: 1.0, green: 0.216, blue: 0.373)) // BabyPass pink
    }
}

// MARK: - Sign In Prompt (shown for gated tabs)

struct SignInPromptView: View {
    let feature: String
    @State private var showSignIn = false
    @State private var showSignUp = false
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.babyPassPink.opacity(0.3), Color.babyPassPink.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 44))
                            .foregroundColor(.babyPassPink)
                    )

                Text("Sign in to \(feature)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Create a free account or sign in to get started.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    Button {
                        showSignIn = true
                    } label: {
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.babyPassPink)
                            .cornerRadius(14)
                    }

                    Button {
                        showSignUp = true
                    } label: {
                        Text("Create Account")
                            .fontWeight(.semibold)
                            .foregroundColor(.babyPassPink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.babyPassPink.opacity(0.1))
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showSignIn) {
                SignInView(showCloseButton: true)
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
                    .environmentObject(authService)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
        .environmentObject(DataService())
}
