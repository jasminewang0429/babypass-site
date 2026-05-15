import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @State private var showDeleteConfirmation = false
    @State private var showDeleteError = false
    @State private var isDeleting = false
    @State private var profilePhotoURL: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isUploadingPhoto = false
    @State private var joinedYear: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Profile header
                    VStack(spacing: 10) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let urlString = profilePhotoURL,
                                   let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(Circle())
                                        default:
                                            profilePlaceholder
                                        }
                                    }
                                } else {
                                    profilePlaceholder
                                }

                                // Camera badge
                                Circle()
                                    .fill(Color.babyPassPink)
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 2, y: 2)
                            }
                        }
                        .disabled(isUploadingPhoto)
                        .overlay {
                            if isUploadingPhoto {
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 80, height: 80)
                                    .overlay(ProgressView().tint(.white))
                            }
                        }

                        Text(authService.userName.isEmpty ? authService.userEmail : authService.userName)
                            .font(.title2)
                            .fontWeight(.bold)

                        if !joinedYear.isEmpty {
                            Text("Joined \(joinedYear)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)

                    // Menu section
                    VStack(spacing: 0) {
                        NavigationLink {
                            MyListingsView()
                                .environmentObject(authService)
                                .environmentObject(dataService)
                        } label: {
                            ProfileMenuRow(
                                icon: "tag.fill",
                                title: "My Listings",
                                color: .babyPassPink
                            )
                        }

                        Divider()
                            .padding(.leading, 56)

                        NavigationLink {
                            SavedItemsView()
                                .environmentObject(authService)
                                .environmentObject(dataService)
                        } label: {
                            ProfileMenuRow(
                                icon: "heart.fill",
                                title: "Saved Items",
                                color: .red
                            )
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(14)

                    // Legal & Support
                    VStack(spacing: 0) {
                        Link(destination: URL(string: "mailto:jasminewang0429@gmail.com?subject=BabyPass%20Feedback")!) {
                            ProfileMenuRow(
                                icon: "envelope.fill",
                                title: "Send Feedback",
                                color: .blue
                            )
                        }

                        Divider()
                            .padding(.leading, 56)

                        Link(destination: URL(string: "https://jasminewang0429.github.io/babypass-site/terms-of-use.html")!) {
                            ProfileMenuRow(
                                icon: "doc.text.fill",
                                title: "Terms of Use",
                                color: .gray
                            )
                        }

                        Divider()
                            .padding(.leading, 56)

                        Link(destination: URL(string: "https://jasminewang0429.github.io/babypass-site/privacy-policy.html")!) {
                            ProfileMenuRow(
                                icon: "lock.shield.fill",
                                title: "Privacy Policy",
                                color: .gray
                            )
                        }

                        Divider()
                            .padding(.leading, 56)

                        Link(destination: URL(string: "https://jasminewang0429.github.io/babypass-site/support.html")!) {
                            ProfileMenuRow(
                                icon: "questionmark.circle.fill",
                                title: "Support",
                                color: .gray
                            )
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(14)

                    // Sign out
                    Button {
                        authService.signOut()
                    } label: {
                        Text("Sign Out")
                            .font(.body)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                    }

                    // Delete account
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        if isDeleting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.red)
                                Text("Deleting Account...")
                                    .font(.body)
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                        } else {
                            Text("Delete Account")
                                .font(.body)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemBackground))
                                .cornerRadius(14)
                        }
                    }
                    .disabled(isDeleting)

                    Text("BabyPass v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This will permanently remove all your data, listings, and messages. This action cannot be undone.")
            }
            .alert("Unable to Delete", isPresented: $showDeleteError) {
                Button("OK") { }
            } message: {
                Text("There was a problem deleting your account. You may need to sign out, sign back in, and try again.")
            }
            .onAppear {
                dataService.fetchProfilePhotoURL { url in
                    profilePhotoURL = url
                }
                dataService.fetchJoinedYear { year in
                    joinedYear = year
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem = newItem else { return }
                isUploadingPhoto = true
                newItem.loadTransferable(type: Data.self) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let data):
                            if let data = data, let image = UIImage(data: data) {
                                dataService.uploadProfilePhoto(image) { url in
                                    isUploadingPhoto = false
                                    if let url = url {
                                        profilePhotoURL = url
                                    }
                                }
                            } else {
                                isUploadingPhoto = false
                            }
                        case .failure:
                            isUploadingPhoto = false
                        }
                    }
                }
            }
        }
    }

    private var profilePlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 1, green: 0.6, blue: 0.62), Color(red: 0.996, green: 0.812, blue: 0.937)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 80, height: 80)
            .overlay(
                Text(String(authService.userName.prefix(1)).uppercased())
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }

    private func deleteAccount() {
        isDeleting = true
        authService.deleteAccount { success in
            isDeleting = false
            if !success {
                showDeleteError = true
            }
        }
    }
}

// MARK: - Profile Menu Row

struct ProfileMenuRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 28)

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
        .environmentObject(DataService())
}
