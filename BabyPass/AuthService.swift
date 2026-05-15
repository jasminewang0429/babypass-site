import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

class AuthService: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isSignedIn = user != nil
                self?.userEmail = user?.email ?? ""
                self?.userName = user?.displayName ?? ""
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Sign In
    func signIn(email: String, password: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        errorMessage = nil
        isLoading = true
        Auth.auth().signIn(withEmail: trimmedEmail, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Create Account
    func createAccount(name: String, email: String, password: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        errorMessage = nil
        isLoading = true
        Auth.auth().createUser(withEmail: trimmedEmail, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                // Set display name and save profile to Firestore
                if let user = result?.user {
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = name
                    changeRequest.commitChanges { _ in
                        DispatchQueue.main.async {
                            self?.userName = name
                        }
                    }
                    // Save user profile to Firestore
                    let profile: [String: Any] = [
                        "displayName": name,
                        "email": trimmedEmail,
                        "rating": 5.0,
                        "salesCount": 0,
                        "listingsCount": 0,
                        "verifiedParent": false,
                        "createdAt": Timestamp(date: Date())
                    ]
                    Firestore.firestore().collection("users").document(user.uid).setData(profile, merge: true)
                }
            }
        }
    }

    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Account
    func deleteAccount(completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false)
            return
        }
        isLoading = true
        let uid = user.uid
        let db = Firestore.firestore()

        // Delete user's listings
        db.collection("listings").whereField("sellerUid", isEqualTo: uid).getDocuments { snapshot, _ in
            let batch = db.batch()
            snapshot?.documents.forEach { batch.deleteDocument($0.reference) }

            // Delete user's saved listings subcollection
            db.collection("users").document(uid).collection("savedListings").getDocuments { savedSnapshot, _ in
                savedSnapshot?.documents.forEach { batch.deleteDocument($0.reference) }

                // Delete user profile
                batch.deleteDocument(db.collection("users").document(uid))

                // Commit all deletions
                batch.commit { _ in
                    // Delete Firebase Auth account
                    user.delete { [weak self] error in
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            if let error = error {
                                self?.errorMessage = error.localizedDescription
                                completion(false)
                            } else {
                                completion(true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reset Password
    func resetPassword(email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        errorMessage = nil
        isLoading = true
        Auth.auth().sendPasswordReset(withEmail: trimmedEmail) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
