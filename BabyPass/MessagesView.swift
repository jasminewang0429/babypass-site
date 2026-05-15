import SwiftUI
import FirebaseAuth

struct MessagesView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @State private var selectedConversation: Conversation? = nil

    private var currentUid: String {
        Auth.auth().currentUser?.uid ?? authService.userEmail
    }

    var body: some View {
        NavigationStack {
            Group {
                if dataService.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No messages yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Start a conversation by messaging a seller")
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(dataService.conversations) { conv in
                            Button {
                                selectedConversation = conv
                            } label: {
                                ConversationRow(conversation: conv, currentUid: currentUid)
                            }
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Messages")
            .onAppear {
                dataService.listenToConversations()
            }
            .sheet(item: $selectedConversation) { conv in
                NavigationStack {
                    ChatView(conversation: conv)
                        .environmentObject(authService)
                        .environmentObject(dataService)
                }
            }
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let currentUid: String

    private var otherName: String { conversation.displayName(for: currentUid) }
    private var unread: Int { conversation.unreadCount(for: currentUid) }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1, green: 0.6, blue: 0.62), Color(red: 0.996, green: 0.812, blue: 0.937)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(otherName.prefix(1)))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(otherName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(conversation.timeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("\(conversation.listingTitle) · \(conversation.lastMessage)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if unread > 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }
}

extension Conversation {
    var timeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastMessageAt, relativeTo: Date())
    }
}

#Preview {
    MessagesView()
        .environmentObject(AuthService())
        .environmentObject(DataService())
}
