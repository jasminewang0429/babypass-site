import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreedToTerms = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 10)

                    // Header
                    VStack(spacing: 8) {
                        Text("Create Account")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Join your local parent community")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    // Form fields
                    VStack(spacing: 14) {
                        AuthTextField(label: "NAME", placeholder: "Your name", text: $name)

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

                            SecureField("At least 6 characters", text: $password)
                                .textContentType(.newPassword)
                                .padding(14)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("CONFIRM PASSWORD")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .tracking(0.3)

                            SecureField("Re-enter password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding(14)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }
                    }

                    // Validation message
                    if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords don't match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    // Error message
                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Create account button
                    Button {
                        authService.createAccount(name: name, email: email, password: password)
                    } label: {
                        Group {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
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

                    // Terms agreement checkbox
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            agreedToTerms.toggle()
                        } label: {
                            Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundColor(agreedToTerms ? .babyPassPink : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("I agree to the ")
                                .font(.caption) +
                            Text("[Terms of Use](https://jasminewang0429.github.io/babypass-site/terms-of-use.html)")
                                .font(.caption) +
                            Text(" and ")
                                .font(.caption) +
                            Text("[Privacy Policy](https://jasminewang0429.github.io/babypass-site/privacy-policy.html)")
                                .font(.caption)

                            Text("Including zero tolerance for objectionable content or abusive users.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)

                    // Already have account
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(.secondary)
                        Button {
                            dismiss()
                        } label: {
                            Text("Sign In")
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
    }

    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 6 && password == confirmPassword && agreedToTerms
    }
}

// MARK: - Reusable text field

struct AuthTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .tracking(0.3)

            TextField(placeholder, text: $text)
                .padding(14)
                .background(Color(.systemBackground))
                .cornerRadius(12)
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthService())
}
