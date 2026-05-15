import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class DataService: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listingsListener: ListenerRegistration?
    private var conversationsListener: ListenerRegistration?
    /// Auth-state observer used to retry `listenToConversations()` once Firebase
    /// Auth has rehydrated the user (handles the cold-launch race where the
    /// Messages tab appears before `currentUser` is non-nil).
    fileprivate var pendingConversationsListenerHandle: AuthStateDidChangeListenerHandle?

    deinit {
        listingsListener?.remove()
        conversationsListener?.remove()
        if let handle = pendingConversationsListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Listings

    /// Listen to all active listings in real time
    func listenToListings() {
        listingsListener?.remove()
        listingsListener = db.collection("listings")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching listings: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                DispatchQueue.main.async {
                    self?.listings = documents.compactMap { doc in
                        try? doc.data(as: Listing.self)
                    }
                    .filter { $0.status == .active }
                    .sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    /// Post a new listing with optional photos
    func postListing(
        title: String,
        price: Double,
        originalPrice: Double?,
        category: Listing.ListingCategory,
        condition: Listing.ItemCondition,
        description: String,
        photos: [UIImage],
        latitude: Double,
        longitude: Double,
        completion: @escaping (Bool) -> Void
    ) {
        guard let user = Auth.auth().currentUser else {
            completion(false)
            return
        }

        isLoading = true

        // Upload photos first, then create listing
        uploadPhotos(photos, listingId: UUID().uuidString) { [weak self] photoURLs in
            let listing = Listing(
                id: nil,
                sellerUid: user.uid,
                sellerName: user.displayName ?? "Anonymous",
                title: title,
                price: price,
                originalPrice: originalPrice,
                category: category,
                condition: condition,
                description: description,
                photoURLs: photoURLs,
                latitude: latitude,
                longitude: longitude,
                status: .active,
                createdAt: Date(),
                viewCount: 0
            )

            do {
                try self?.db.collection("listings").addDocument(from: listing)
                DispatchQueue.main.async {
                    self?.isLoading = false
                    completion(true)
                }
            } catch {
                print("Error posting listing: \(error)")
                DispatchQueue.main.async {
                    self?.isLoading = false
                    completion(false)
                }
            }
        }
    }

    /// Upload photos to Firebase Storage
    private func uploadPhotos(_ images: [UIImage], listingId: String, completion: @escaping ([String]) -> Void) {
        guard !images.isEmpty else {
            completion([])
            return
        }

        var uploadedURLs: [String] = []
        let group = DispatchGroup()

        for (index, image) in images.enumerated() {
            guard let data = image.jpegData(compressionQuality: 0.6) else { continue }
            let ref = storage.reference().child("listings/\(listingId)/photo_\(index).jpg")

            group.enter()
            ref.putData(data) { _, error in
                if let error = error {
                    print("Upload error: \(error)")
                    group.leave()
                    return
                }
                ref.downloadURL { url, _ in
                    if let url = url {
                        uploadedURLs.append(url.absoluteString)
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            completion(uploadedURLs)
        }
    }

    // MARK: - Conversations

    /// Listen to conversations for the current user.
    /// NOTE: We deliberately do NOT chain `.order(by: "lastMessageAt")` on the
    /// Firestore query. Combined with `arrayContains` on `participants` it would
    /// require a composite index — without that index the listener would silently
    /// error and the seller would see no conversations at all (which was the
    /// "I didn't receive anything" symptom). Instead, we sort client-side.
    func listenToConversations() {
        // If Auth hasn't restored yet (e.g., cold launch from a deep link before
        // Firebase has rehydrated the session), retry once the auth state is
        // ready. Without this guard the listener silently no-ops and the user
        // sees an empty list with no recovery.
        guard let user = Auth.auth().currentUser else {
            if pendingConversationsListenerHandle == nil {
                pendingConversationsListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, signedInUser in
                    guard let self = self, signedInUser != nil else { return }
                    if let handle = self.pendingConversationsListenerHandle {
                        Auth.auth().removeStateDidChangeListener(handle)
                        self.pendingConversationsListenerHandle = nil
                    }
                    self.listenToConversations()
                }
            }
            return
        }

        conversationsListener?.remove()
        conversationsListener = db.collection("conversations")
            .whereField("participants", arrayContains: user.uid)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching conversations: \(error.localizedDescription)")
                }
                // Only clobber existing data when we actually got a snapshot back.
                // A transient error keeps the previous list visible.
                guard let documents = snapshot?.documents else { return }
                let decoded = documents.compactMap { doc in
                    try? doc.data(as: Conversation.self)
                }
                .sorted { $0.lastMessageAt > $1.lastMessageAt }
                DispatchQueue.main.async {
                    self?.conversations = decoded
                }
            }
    }

    /// Start or find an existing conversation
    func startConversation(
        with sellerUid: String,
        sellerName: String,
        listingId: String,
        listingTitle: String,
        initialMessage: String,
        completion: @escaping (Conversation?) -> Void
    ) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }

        // Resolve the buyer's display name with a sensible fallback chain so the
        // seller's chat list never shows a blank or "Anonymous" contact.
        let buyerName: String = {
            if let n = user.displayName, !n.isEmpty { return n }
            if let e = user.email, !e.isEmpty { return String(e.split(separator: "@").first ?? "Anonymous") }
            return "Anonymous"
        }()

        // Check if conversation already exists for this listing between these users
        db.collection("conversations")
            .whereField("listingId", isEqualTo: listingId)
            .whereField("participants", arrayContains: user.uid)
            .getDocuments { [weak self] snapshot, error in
                if let existing = snapshot?.documents.first,
                   var conv = try? existing.data(as: Conversation.self) {
                    // Backfill the current user's entry in participantNames so legacy
                    // conversations auto-heal (without overwriting the other side).
                    var names = conv.participantNames ?? [:]
                    if names[user.uid] != buyerName {
                        names[user.uid] = buyerName
                        if names[sellerUid] == nil { names[sellerUid] = sellerName }
                        self?.db.collection("conversations").document(existing.documentID)
                            .setData(["participantNames": names], merge: true)
                        conv.participantNames = names
                    }
                    completion(conv)
                    return
                }

                // Create new conversation. Per-participant maps so the seller sees
                // the buyer's name (and her own unread badge) on the Messages tab.
                let conversation = Conversation(
                    id: nil,
                    participants: [user.uid, sellerUid],
                    listingId: listingId,
                    listingTitle: listingTitle,
                    otherUserName: sellerName,
                    lastMessage: initialMessage,
                    lastMessageAt: Date(),
                    unreadCount: 1,
                    participantNames: [user.uid: buyerName, sellerUid: sellerName],
                    unreadCounts: [user.uid: 0, sellerUid: 1]
                )

                do {
                    var docRef: DocumentReference?
                    docRef = try self?.db.collection("conversations").addDocument(from: conversation) { error in
                        if let error = error {
                            print("Error creating conversation document: \(error)")
                            DispatchQueue.main.async { completion(nil) }
                            return
                        }
                        // Conversation document is now confirmed by the server.
                        // Only THEN add the initial message so we never end up
                        // with an orphan message attached to a conversation that
                        // failed to be created.
                        guard let convId = docRef?.documentID else {
                            DispatchQueue.main.async { completion(nil) }
                            return
                        }
                        let message = Message(
                            id: nil,
                            conversationId: convId,
                            senderUid: user.uid,
                            text: initialMessage,
                            sentAt: Date(),
                            read: false
                        )
                        try? self?.db.collection("conversations").document(convId)
                            .collection("messages").addDocument(from: message)

                        var newConv = conversation
                        newConv.id = convId
                        DispatchQueue.main.async { completion(newConv) }
                    }
                } catch {
                    print("Error creating conversation: \(error)")
                    DispatchQueue.main.async { completion(nil) }
                }
            }
    }

    // MARK: - Messages

    /// Listen to messages in a conversation in real time
    func listenToMessages(conversationId: String, completion: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "sentAt", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                let messages = documents.compactMap { doc in
                    try? doc.data(as: Message.self)
                }
                DispatchQueue.main.async {
                    completion(messages)
                }
            }
    }

    /// Send a message in a conversation
    func sendMessage(conversationId: String, text: String) {
        guard let user = Auth.auth().currentUser else { return }

        let message = Message(
            id: nil,
            conversationId: conversationId,
            senderUid: user.uid,
            text: text,
            sentAt: Date(),
            read: false
        )

        // Add message to subcollection
        try? db.collection("conversations").document(conversationId)
            .collection("messages").addDocument(from: message)

        // Resolve the recipient by reading the conversation's participants and
        // taking the uid that is NOT the current user. We do this read-modify
        // style so we can target the correct unreadCounts.{recipientUid} key
        // — atomic increment guarantees concurrent sends don't lose updates.
        let convRef = db.collection("conversations").document(conversationId)
        convRef.getDocument { snapshot, _ in
            let participants = snapshot?.data()?["participants"] as? [String] ?? []
            let recipientUid = participants.first(where: { $0 != user.uid })
            var update: [String: Any] = [
                "lastMessage": text,
                "lastMessageAt": Timestamp(date: Date())
            ]
            if let recipientUid = recipientUid {
                update["unreadCounts.\(recipientUid)"] = FieldValue.increment(Int64(1))
            }
            convRef.setData(update, merge: true)
        }
    }

    /// Mark all messages in a conversation as read for the current user.
    /// Uses a dotted-path field update so only the current user's entry in the
    /// `unreadCounts` map is touched. Firestore's setData(merge:) REPLACES
    /// nested maps wholesale (it does not union them), so a naive
    /// setData(["unreadCounts": [uid: 0]], merge: true) would drop the OTHER
    /// participant's badge. The dotted-path form on updateData is the
    /// canonical Firestore API for "patch one entry, leave siblings alone".
    func markConversationRead(conversationId: String) {
        guard let user = Auth.auth().currentUser else { return }
        db.collection("conversations").document(conversationId).updateData([
            "unreadCounts.\(user.uid)": 0
        ])
    }

    // MARK: - My Listings

    /// Fetch listings posted by the current user
    func fetchMyListings(completion: @escaping ([Listing]) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion([])
            return
        }

        db.collection("listings")
            .whereField("sellerUid", isEqualTo: user.uid)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching my listings: \(error?.localizedDescription ?? "Unknown")")
                    completion([])
                    return
                }
                let listings = documents.compactMap { doc in
                    try? doc.data(as: Listing.self)
                }.sorted { $0.createdAt > $1.createdAt }
                DispatchQueue.main.async {
                    completion(listings)
                }
            }
    }

    /// Update listing status (available, pending, sold)
    func updateListingStatus(listingId: String, status: Listing.ListingStatus, completion: @escaping (Bool) -> Void) {
        db.collection("listings").document(listingId).updateData([
            "status": status.rawValue
        ]) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }

    /// Mark a listing as sold (convenience)
    func markListingAsSold(listingId: String, completion: @escaping (Bool) -> Void) {
        updateListingStatus(listingId: listingId, status: .sold, completion: completion)
    }

    /// Delete a listing
    func deleteListing(listingId: String, completion: @escaping (Bool) -> Void) {
        db.collection("listings").document(listingId).delete { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }

    // MARK: - Saved Items

    /// Save a listing for the current user
    func saveListing(listingId: String) {
        guard let user = Auth.auth().currentUser else { return }
        db.collection("users").document(user.uid)
            .collection("savedListings").document(listingId)
            .setData(["savedAt": Timestamp(date: Date())])
    }

    /// Unsave a listing
    func unsaveListing(listingId: String) {
        guard let user = Auth.auth().currentUser else { return }
        db.collection("users").document(user.uid)
            .collection("savedListings").document(listingId)
            .delete()
    }

    /// Check if a listing is saved
    func isListingSaved(listingId: String, completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false)
            return
        }
        db.collection("users").document(user.uid)
            .collection("savedListings").document(listingId)
            .getDocument { snapshot, _ in
                DispatchQueue.main.async {
                    completion(snapshot?.exists == true)
                }
            }
    }

    /// Fetch all saved listings
    func fetchSavedListings(completion: @escaping ([Listing]) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion([])
            return
        }

        db.collection("users").document(user.uid)
            .collection("savedListings")
            .order(by: "savedAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                let listingIds = documents.map { $0.documentID }
                var fetchedListings: [Listing] = []
                let group = DispatchGroup()

                for id in listingIds {
                    group.enter()
                    self?.db.collection("listings").document(id).getDocument { doc, _ in
                        if let doc = doc, let listing = try? doc.data(as: Listing.self) {
                            fetchedListings.append(listing)
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    completion(fetchedListings)
                }
            }
    }

    // MARK: - User Profile

    /// Create or update user profile in Firestore
    func saveUserProfile(uid: String, displayName: String, email: String) {
        let profile: [String: Any] = [
            "displayName": displayName,
            "email": email,
            "rating": 5.0,
            "salesCount": 0,
            "listingsCount": 0,
            "verifiedParent": false,
            "createdAt": Timestamp(date: Date())
        ]
        db.collection("users").document(uid).setData(profile, merge: true)
    }

    // MARK: - Profile Photo

    /// Upload profile photo and save URL to Firestore
    func uploadProfilePhoto(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }

        guard let data = image.jpegData(compressionQuality: 0.7) else {
            completion(nil)
            return
        }

        let ref = storage.reference().child("profilePhotos/\(user.uid).jpg")
        ref.putData(data) { _, error in
            if let error = error {
                print("Profile photo upload error: \(error)")
                completion(nil)
                return
            }
            ref.downloadURL { url, _ in
                guard let url = url else {
                    completion(nil)
                    return
                }
                let urlString = url.absoluteString
                // Save to Firestore user profile
                self.db.collection("users").document(user.uid).updateData([
                    "profilePhotoURL": urlString
                ])
                DispatchQueue.main.async {
                    completion(urlString)
                }
            }
        }
    }

    /// Fetch the current user's profile photo URL
    func fetchProfilePhotoURL(completion: @escaping (String?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        db.collection("users").document(user.uid).getDocument { snapshot, _ in
            let url = snapshot?.data()?["profilePhotoURL"] as? String
            DispatchQueue.main.async {
                completion(url)
            }
        }
    }

    /// Fetch the year the current user joined
    func fetchJoinedYear(completion: @escaping (String) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion("")
            return
        }
        db.collection("users").document(user.uid).getDocument { snapshot, _ in
            DispatchQueue.main.async {
                if let timestamp = snapshot?.data()?["createdAt"] as? Timestamp {
                    let year = Calendar.current.component(.year, from: timestamp.dateValue())
                    completion(String(year))
                } else if let creationDate = user.metadata.creationDate {
                    let year = Calendar.current.component(.year, from: creationDate)
                    completion(String(year))
                } else {
                    completion("")
                }
            }
        }
    }

    // MARK: - Report & Block

    /// Report a listing or user
    func reportContent(reportedItemId: String, reportedUserId: String, reason: String, type: String) {
        guard let user = Auth.auth().currentUser else { return }

        let report: [String: Any] = [
            "reporterUid": user.uid,
            "reportedItemId": reportedItemId,
            "reportedUserId": reportedUserId,
            "reason": reason,
            "type": type,
            "status": "pending",
            "createdAt": Timestamp(date: Date())
        ]
        db.collection("reports").addDocument(data: report)
    }

    /// Block a user
    func blockUser(blockedUid: String) {
        guard let user = Auth.auth().currentUser else { return }
        db.collection("users").document(user.uid)
            .collection("blockedUsers").document(blockedUid)
            .setData(["blockedAt": Timestamp(date: Date())])
    }

    /// Unblock a user
    func unblockUser(blockedUid: String) {
        guard let user = Auth.auth().currentUser else { return }
        db.collection("users").document(user.uid)
            .collection("blockedUsers").document(blockedUid)
            .delete()
    }

    /// Check if a user is blocked
    func isUserBlocked(uid: String, completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false)
            return
        }
        db.collection("users").document(user.uid)
            .collection("blockedUsers").document(uid)
            .getDocument { snapshot, _ in
                DispatchQueue.main.async {
                    completion(snapshot?.exists == true)
                }
            }
    }
}
