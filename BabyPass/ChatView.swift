import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatView: View {
    let conversation: Conversation
    var initialMessage: String? = nil
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [Message] = []
    @State private var newText = ""
    @State private var messageListener: ListenerRegistration?
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var showReportedAlert = false
    @State private var showBlockedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Chat header info
            HStack(spacing: 10) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1, green: 0.6, blue: 0.62), Color(red: 0.996, green: 0.812, blue: 0.937)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text(String(otherName.prefix(1)))
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(otherName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("About: \(conversation.listingTitle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(alignment: .bottom) {
                Divider()
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg, currentUserUid: currentUid)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastId = messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            // Input bar
            HStack(spacing: 8) {
                TextField("Message...", text: $newText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(newText.isEmpty ? .gray : .blue)
                }
                .disabled(newText.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(alignment: .top) {
                Divider()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showReportSheet = true
                    } label: {
                        Label("Report User", systemImage: "flag")
                    }

                    Button {
                        showBlockConfirmation = true
                    } label: {
                        Label("Block User", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReportSheet) {
            ReportView(
                itemTitle: otherName,
                onSubmit: { reason in
                    let otherUid = conversation.participants.first { $0 != currentUid } ?? ""
                    dataService.reportContent(
                        reportedItemId: conversation.id ?? "",
                        reportedUserId: otherUid,
                        reason: reason,
                        type: "user"
                    )
                    showReportSheet = false
                    showReportedAlert = true
                }
            )
        }
        .alert("User Reported", isPresented: $showReportedAlert) {
            Button("OK") { }
        } message: {
            Text("Thank you for reporting. We will review this within 24 hours and take appropriate action.")
        }
        .alert("Block \(otherName)?", isPresented: $showBlockConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                let otherUid = conversation.participants.first { $0 != currentUid } ?? ""
                dataService.blockUser(blockedUid: otherUid)
                showBlockedAlert = true
            }
        } message: {
            Text("You will no longer receive messages from this user or see their listings.")
        }
        .alert("User Blocked", isPresented: $showBlockedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("\(otherName) has been blocked.")
        }
        .onAppear {
            startListening()
            // Skip the write for the not-yet-created "new" conversation and when there's nothing to clear.
            if let convId = conversation.id, convId != "new",
               conversation.unreadCount(for: currentUid) > 0 {
                dataService.markConversationRead(conversationId: convId)
            }
        }
        .onDisappear {
            messageListener?.remove()
        }
    }

    private var currentUid: String {
        // Use Firebase UID for Firestore-based messages, fall back to email for sample data
        return Auth.auth().currentUser?.uid ?? authService.userEmail
    }

    /// Name of the OTHER participant (the one this user is chatting with).
    /// Resolves correctly whether the current user is the buyer OR the seller.
    private var otherName: String {
        conversation.displayName(for: currentUid)
    }

    private func startListening() {
        guard let convId = conversation.id, convId != "new" else {
            if let initial = initialMessage, !initial.isEmpty {
                let msg = Message(
                    id: UUID().uuidString,
                    conversationId: conversation.id ?? "new",
                    senderUid: currentUid,
                    text: initial,
                    sentAt: Date(),
                    read: false
                )
                messages.append(msg)
            }
            return
        }

        // Listen to real Firestore messages
        messageListener = dataService.listenToMessages(conversationId: convId) { [self] fetchedMessages in
            self.messages = fetchedMessages
        }

        // Note: initial message is already sent by startConversation in DataService
        // Do NOT re-send here to avoid duplicates
    }

    private func sendMessage() {
        guard !newText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        if let convId = conversation.id, convId != "new" {
            // Send via Firestore
            dataService.sendMessage(conversationId: convId, text: newText)
        } else {
            // Local fallback
            let msg = Message(
                id: UUID().uuidString,
                conversationId: conversation.id ?? "new",
                senderUid: currentUid,
                text: newText,
                sentAt: Date(),
                read: false
            )
            messages.append(msg)
        }
        newText = ""
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    var currentUserUid: String = ""

    private var isMe: Bool {
        message.senderUid == currentUserUid
    }

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 60) }

            Text(message.text)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isMe ? Color.blue : Color(.systemGray5))
                .foregroundColor(isMe ? .white : .primary)
                .cornerRadius(18, corners: isMe
                    ? [.topLeft, .topRight, .bottomLeft]
                    : [.topLeft, .topRight, .bottomRight])

            if !isMe { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Rounded Corners Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        ChatView(conversation: Conversation(
            id: "preview",
            participants: ["me", "other"],
            listingId: "preview-listing",
            listingTitle: "Graco Car Seat",
            otherUserName: "Emma R.",
            lastMessage: "Sounds good! I can meet at the park tomorrow.",
            lastMessageAt: Date(),
            unreadCount: 1
        ))
            .environmentObject(AuthService())
            .environmentObject(DataService())
    }
}
