import Foundation
import FirebaseFirestore

// MARK: - Listing

struct Listing: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var sellerUid: String
    var sellerName: String
    var title: String
    var price: Double
    var originalPrice: Double?
    var category: ListingCategory
    var condition: ItemCondition
    var description: String
    var photoURLs: [String]
    var latitude: Double
    var longitude: Double
    var status: ListingStatus
    var createdAt: Date
    var viewCount: Int

    enum ListingCategory: String, Codable, CaseIterable {
        case gear = "Gear"
        case toys = "Toys"
        case books = "Books"
        case clothes = "Clothes"
        case feeding = "Feeding"
        case bath = "Bath"
        case nursery = "Nursery"
        case other = "Other"

        var emoji: String {
            switch self {
            case .gear: return "🚗"
            case .toys: return "🧸"
            case .books: return "📚"
            case .clothes: return "👕"
            case .feeding: return "🍼"
            case .bath: return "🛁"
            case .nursery: return "🛏️"
            case .other: return "📦"
            }
        }
    }

    enum ItemCondition: String, Codable, CaseIterable {
        case likeNew = "Like New"
        case good = "Good"
        case fair = "Fair"
    }

    enum ListingStatus: String, Codable, CaseIterable {
        case active
        case pending
        case sold
        case removed

        var displayName: String {
            switch self {
            case .active: return "Available"
            case .pending: return "Pending Pickup"
            case .sold: return "Sold"
            case .removed: return "Removed"
            }
        }

        var color: String {
            switch self {
            case .active: return "green"
            case .pending: return "orange"
            case .sold: return "red"
            case .removed: return "gray"
            }
        }

        var icon: String {
            switch self {
            case .active: return "checkmark.circle.fill"
            case .pending: return "clock.fill"
            case .sold: return "bag.fill"
            case .removed: return "xmark.circle.fill"
            }
        }

        /// Statuses that sellers can set on their listings
        static var sellerOptions: [ListingStatus] {
            [.active, .pending, .sold]
        }
    }
}

// MARK: - User Profile

struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var displayName: String
    var photoURL: String?
    var latitude: Double?
    var longitude: Double?
    var rating: Double
    var salesCount: Int
    var listingsCount: Int
    var verifiedParent: Bool
    var createdAt: Date
}

// MARK: - Conversation

struct Conversation: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var participants: [String]
    var listingId: String
    var listingTitle: String
    // Legacy single-name field (kept for backward compatibility with old docs).
    // New documents populate participantNames instead, but this stays optional
    // so older docs still decode without crashing.
    var otherUserName: String = ""
    var lastMessage: String
    var lastMessageAt: Date
    // Legacy single-counter field (kept for backward compatibility).
    var unreadCount: Int = 0
    // Per-participant maps: each user gets their own display name and unread badge.
    var participantNames: [String: String]? = nil
    var unreadCounts: [String: Int]? = nil

    /// Name of the OTHER participant from the current user's perspective.
    /// Falls back to the legacy `otherUserName` for documents that pre-date the map.
    func displayName(for currentUid: String) -> String {
        if let names = participantNames, !names.isEmpty {
            if let otherUid = participants.first(where: { $0 != currentUid }),
               let name = names[otherUid], !name.isEmpty {
                return name
            }
        }
        return otherUserName
    }

    /// Unread count for the current user. Falls back to legacy scalar when the
    /// per-user map is absent.
    func unreadCount(for currentUid: String) -> Int {
        if let counts = unreadCounts {
            return counts[currentUid] ?? 0
        }
        return unreadCount
    }
}

// MARK: - Message

struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    var conversationId: String
    var senderUid: String
    var text: String
    var sentAt: Date
    var read: Bool
}
