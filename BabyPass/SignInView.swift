import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showResetPassword = false
    @State private var resetEmail = ""
    @State private var showResetAlert = false
    var showCloseButton = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Logo area
                    VStack(spacing: 8) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.babyPassPink, Color(red: 0.996, green: 0.812, blue: 0.937)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            )

                        Text("BabyPass")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Buy & sell baby items nearby")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 16)

                    // Form fields
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EMAIL")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .tracking(0.3)

                            TextField("you@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("PASSWORD")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .tracking(0.3)

                            SecureField("Enter your password", text: $password)
                                .textContentType(.password)
                                .padding(14)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }
                    }

                    // Error message
                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Sign in button
                    Button {
                        authService.signIn(email: email, password: password)
                    } label: {
                        Group {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.babyPassPink : Color.gray)
                        .cornerRadius(14)
                    }
                    .disabled(!isFormValid || authService.isLoading)

                    // Forgot password
                    Button {
                        resetEmail = email
                        showResetPassword = true
                    } label: {
                        Text("Forgot password?")
                            .font(.subheadline)
                            .foregroundColor(.babyPassPink)
                    }

                    Spacer().frame(height: 20)

                    // Sign up link
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        Button {
                            showSignUp = true
                        } label: {
                            Text("Sign Up")
                                .fontWeight(.semibold)
                                .foregroundColor(.babyPassPink)
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showCloseButton {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
                    .environmentObject(authService)
            }
            .alert("Reset Password", isPresented: $showResetPassword) {
                TextField("Email", text: $resetEmail)
                Button("Send Reset Link") {
                    authService.resetPassword(email: resetEmail)
                    showResetAlert = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter your email and we'll send you a link to reset your password.")
            }
            .alert("Check Your Email", isPresented: $showResetAlert) {
                Button("OK") { }
            } message: {
                Text("If an account exists for \(resetEmail), a password reset link has been sent.")
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthService())
}
