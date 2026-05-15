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
    // so older docs and SampleData still decode without crashing.
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

// MARK: - Sample Data for Development

struct SampleData {
    static let listings: [Listing] = [
        Listing(id: "1", sellerUid: "u1", sellerName: "Emma R.",
                title: "Graco 4Ever Convertible Car Seat",
                price: 120, originalPrice: 299,
                category: .gear, condition: .likeNew,
                description: "Used for 8 months. No accidents. Cleaned thoroughly. Expiration 2031. Comes with original manual.",
                photoURLs: [], latitude: 37.4419, longitude: -122.1430,
                status: .active, createdAt: Date(), viewCount: 45),

        Listing(id: "2", sellerUid: "u2", sellerName: "Sarah L.",
                title: "Wooden Montessori Toy Set (12pc)",
                price: 25, originalPrice: 65,
                category: .toys, condition: .good,
                description: "Complete set of wooden toys. Great for 6-18 months. Mild wear on one block.",
                photoURLs: [], latitude: 37.4450, longitude: -122.1600,
                status: .active, createdAt: Date(), viewCount: 23),

        Listing(id: "3", sellerUid: "u3", sellerName: "Maya K.",
                title: "Baby Books Bundle (20 board books)",
                price: 15, originalPrice: 80,
                category: .books, condition: .good,
                description: "20 favorites — Goodnight Moon, Brown Bear, and more. Some well-loved corners!",
                photoURLs: [], latitude: 37.4380, longitude: -122.1350,
                status: .active, createdAt: Date(), viewCount: 67),

        Listing(id: "4", sellerUid: "u4", sellerName: "Nina T.",
                title: "0-12M Clothing Lot (30 pieces)",
                price: 40, originalPrice: 200,
                category: .clothes, condition: .likeNew,
                description: "Mostly Carter's and Gap. Smoke-free home. Washed and folded.",
                photoURLs: [], latitude: 37.4500, longitude: -122.1700,
                status: .active, createdAt: Date(), viewCount: 34),

        Listing(id: "5", sellerUid: "u5", sellerName: "Alex P.",
                title: "Bottle Starter Kit (Dr. Brown's)",
                price: 18, originalPrice: 45,
                category: .feeding, condition: .good,
                description: "6 bottles, sanitized. All nipples stage 1 & 2.",
                photoURLs: [], latitude: 37.4350, longitude: -122.1500,
                status: .active, createdAt: Date(), viewCount: 12),

        Listing(id: "6", sellerUid: "u6", sellerName: "Jen H.",
                title: "Fisher-Price Activity Gym",
                price: 22, originalPrice: 55,
                category: .toys, condition: .good,
                description: "Folds flat for storage. Music works great. Bright colors, all toys attached.",
                photoURLs: [], latitude: 37.4460, longitude: -122.1450,
                status: .active, createdAt: Date(), viewCount: 19),

        Listing(id: "7", sellerUid: "u7", sellerName: "Rachel B.",
                title: "UPPAbaby Vista V2 Stroller",
                price: 450, originalPrice: 970,
                category: .gear, condition: .likeNew,
                description: "Mint condition, all accessories included. Tan leather handle. Bassinet + toddler seat.",
                photoURLs: [], latitude: 37.4410, longitude: -122.1550,
                status: .active, createdAt: Date(), viewCount: 89),

        Listing(id: "8", sellerUid: "u8", sellerName: "Tasha V.",
                title: "Baby Bath Tub + Toys",
                price: 12, originalPrice: 35,
                category: .bath, condition: .good,
                description: "4moms Infant Tub with temperature strip. Includes 5 bath toys.",
                photoURLs: [], latitude: 37.4390, longitude: -122.1380,
                status: .active, createdAt: Date(), viewCount: 8),
    ]

    static let conversations: [Conversation] = [
        Conversation(id: "c1", participants: ["me", "u1"],
                     listingId: "1", listingTitle: "Graco Car Seat",
                     otherUserName: "Emma R.",
                     lastMessage: "Sounds good! I can meet at the park tomorrow.",
                     lastMessageAt: Date(), unreadCount: 1),
        Conversation(id: "c2", participants: ["me", "u3"],
                     listingId: "3", listingTitle: "Baby Books Bundle",
                     otherUserName: "Maya K.",
                     lastMessage: "Perfect, see you at 3!",
                     lastMessageAt: Date().addingTimeInterval(-3600), unreadCount: 0),
        Conversation(id: "c3", participants: ["me", "u7"],
                     listingId: "7", listingTitle: "UPPAbaby Stroller",
                     otherUserName: "Rachel B.",
                     lastMessage: "I'll send a few more photos tonight.",
                     lastMessageAt: Date().addingTimeInterval(-86400), unreadCount: 0),
    ]

    static let messages: [String: [Message]] = [
        "c1": [
            Message(id: "m1", conversationId: "c1", senderUid: "u1", text: "Hi! Is the car seat still available?", sentAt: Date().addingTimeInterval(-7200), read: true),
            Message(id: "m2", conversationId: "c1", senderUid: "me", text: "Yes it is! Would you like to see it this weekend?", sentAt: Date().addingTimeInterval(-6000), read: true),
            Message(id: "m3", conversationId: "c1", senderUid: "u1", text: "That works! Where do you usually meet?", sentAt: Date().addingTimeInterval(-4800), read: true),
            Message(id: "m4", conversationId: "c1", senderUid: "me", text: "I'm near Riverside Park — there's parking right outside.", sentAt: Date().addingTimeInterval(-3600), read: true),
            Message(id: "m5", conversationId: "c1", senderUid: "u1", text: "Sounds good! I can meet at the park tomorrow.", sentAt: Date().addingTimeInterval(-1800), read: false),
        ],
        "c2": [
            Message(id: "m6", conversationId: "c2", senderUid: "u3", text: "Hey! Would you take $12 for the book bundle?", sentAt: Date().addingTimeInterval(-7200), read: true),
            Message(id: "m7", conversationId: "c2", senderUid: "me", text: "Sure, that works!", sentAt: Date().addingTimeInterval(-5400), read: true),
            Message(id: "m8", conversationId: "c2", senderUid: "u3", text: "Perfect, see you at 3!", sentAt: Date().addingTimeInterval(-3600), read: true),
        ],
        "c3": [
            Message(id: "m9", conversationId: "c3", senderUid: "me", text: "Hi Rachel! Does the stroller come with the bassinet?", sentAt: Date().addingTimeInterval(-172800), read: true),
            Message(id: "m10", conversationId: "c3", senderUid: "u7", text: "Yes, it includes the bassinet and rain cover!", sentAt: Date().addingTimeInterval(-90000), read: true),
            Message(id: "m11", conversationId: "c3", senderUid: "u7", text: "I'll send a few more photos tonight.", sentAt: Date().addingTimeInterval(-86400), read: true),
        ],
    ]
}
