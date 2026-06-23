import SwiftUI

struct ListingDetailView: View {
    let listing: Listing
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) private var dismiss
    @State private var isSaved = false
    @State private var showChat = false
    @State private var activeConversation: Conversation? = nil
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var showReportedAlert = false
    @State private var showBlockedAlert = false
    @State private var reportReason = ""
    @State private var showSignInPrompt = false
    @State private var currentPhotoIndex = 0

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [listing.category.gradientStart, listing.category.gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(listing.category.emoji)
                .font(.system(size: 120))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image / photo gallery
                DetailHeroView(
                    listing: listing,
                    currentPhotoIndex: $currentPhotoIndex,
                    placeholder: heroPlaceholder
                )

                VStack(alignment: .leading, spacing: 12) {
                    DetailInfoSection(listing: listing)
                    PickupRow(listing: listing)
                    ListedAgoCaption(createdAt: listing.createdAt)
                    DetailSellerCard(sellerUid: listing.sellerUid, sellerName: listing.sellerName)
                    MoreFromSellerRail(sellerUid: listing.sellerUid, sellerName: listing.sellerName, excludingId: listing.id)
                }
                .padding(16)
                .padding(.bottom, 80)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if let id = listing.id {
                dataService.isListingSaved(listingId: id) { saved in
                    isSaved = saved
                }
                dataService.incrementListingViewCount(listingId: id, sellerUid: listing.sellerUid)
            }
        }
        .overlay(alignment: .bottom) {
            // Action bar
            HStack(spacing: 10) {
                Button {
                    guard authService.isSignedIn else {
                        showSignInPrompt = true
                        return
                    }
                    isSaved.toggle()
                    if let id = listing.id {
                        if isSaved {
                            dataService.saveListing(listingId: id)
                        } else {
                            dataService.unsaveListing(listingId: id)
                        }
                    }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(isSaved ? .babyPassPink : .primary)
                        .frame(width: 54, height: 48)
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }

                Button {
                    guard authService.isSignedIn else {
                        showSignInPrompt = true
                        return
                    }
                    startConversation()
                } label: {
                    Text("Message Seller")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.babyPassPink)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showSignInPrompt) {
            SignInView(showCloseButton: true)
                .environmentObject(authService)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    ShareLink(
                        item: "\(listing.title) — $\(Int(listing.price)) on BabyPass",
                        subject: Text(listing.title),
                        message: Text("Check out this deal on BabyPass: \(listing.title) for $\(Int(listing.price))!")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Menu {
                        Button {
                            showReportSheet = true
                        } label: {
                            Label("Report Listing", systemImage: "flag")
                        }

                        Button {
                            showBlockConfirmation = true
                        } label: {
                            Label("Block Seller", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportView(
                itemTitle: listing.title,
                onSubmit: { reason in
                    dataService.reportContent(
                        reportedItemId: listing.id ?? "",
                        reportedUserId: listing.sellerUid,
                        reason: reason,
                        type: "listing"
                    )
                    showReportSheet = false
                    showReportedAlert = true
                }
            )
        }
        .alert("Listing Reported", isPresented: $showReportedAlert) {
            Button("OK") { }
        } message: {
            Text("Thank you for reporting. We will review this listing within 24 hours and take appropriate action.")
        }
        .alert("Block \(listing.sellerName)?", isPresented: $showBlockConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                dataService.blockUser(blockedUid: listing.sellerUid)
                showBlockedAlert = true
            }
        } message: {
            Text("You will no longer see listings from this user or receive messages from them.")
        }
        .alert("User Blocked", isPresented: $showBlockedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("\(listing.sellerName) has been blocked.")
        }
        .sheet(item: $activeConversation) { conv in
            NavigationStack {
                ChatView(conversation: conv)
                    .environmentObject(authService)
                    .environmentObject(dataService)
            }
        }
    }

    private func startConversation() {
        let message = "Hi! Is \"\(listing.title)\" still available?"
        dataService.startConversation(
            with: listing.sellerUid,
            sellerName: listing.sellerName,
            listingId: listing.id ?? "",
            listingTitle: listing.title,
            initialMessage: message
        ) { conversation in
            if let conv = conversation {
                activeConversation = conv
            }
        }
    }
}

// MARK: - Detail Hero View

struct DetailHeroView<Placeholder: View>: View {
    let listing: Listing
    @Binding var currentPhotoIndex: Int
    let placeholder: Placeholder

    var body: some View {
        if listing.photoURLs.isEmpty {
            placeholder
                .frame(height: 340)
        } else {
            ZStack(alignment: .bottom) {
                TabView(selection: $currentPhotoIndex) {
                    ForEach(listing.photoURLs.indices, id: \.self) { index in
                        AsyncImage(url: URL(string: listing.photoURLs[index])) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure(_):
                                placeholder
                            case .empty:
                                ZStack { placeholder; ProgressView() }
                            @unknown default:
                                placeholder
                            }
                        }
                        .frame(height: 340)
                        .clipped()
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 340)

                if listing.photoURLs.count > 1 {
                    Text("\(currentPhotoIndex + 1)/\(listing.photoURLs.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(10)
                        .padding(.bottom, 12)
                }
            }
        }
    }
}

// MARK: - Detail Info Section

struct DetailInfoSection: View {
    let listing: Listing

    var body: some View {
        Group {
            Text(listing.title)
                .font(.title2)
                .fontWeight(.bold)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("$\(Int(listing.price))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.babyPassPink)

                if let orig = listing.originalPrice {
                    Text("$\(Int(orig))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .strikethrough()

                    let savings = Int(((orig - listing.price) / orig) * 100)
                    Text("\(savings)% off")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(6)
                }
            }

            HStack(spacing: 8) {
                StatusBadge(status: listing.status)
                Badge(text: listing.condition.rawValue, color: .green)
                Badge(text: listing.category.rawValue, color: .blue)
            }

            if listing.viewCount >= 10 {
                Text("👀 \(listing.viewCount) views")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(listing.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(.top, 4)
        }
    }
}

// MARK: - Detail Seller Card

struct DetailSellerCard: View {
    let sellerUid: String
    let sellerName: String

    @EnvironmentObject var dataService: DataService
    @State private var info: DataService.SellerInfo? = nil

    private var displayName: String { info?.displayName ?? sellerName }

    private var statsLine: String? {
        guard let info = info else { return nil }
        var parts: [String] = []
        if info.salesCount > 0 {
            parts.append("\(info.salesCount) \(info.salesCount == 1 ? "sale" : "sales")")
        }
        if info.listingsCount > 0 {
            parts.append("\(info.listingsCount) active \(info.listingsCount == 1 ? "listing" : "listings")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1, green: 0.6, blue: 0.62), Color(red: 0.996, green: 0.812, blue: 0.937)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var initialAvatar: some View {
        Circle()
            .fill(avatarGradient)
            .overlay(
                Text(String(displayName.prefix(1)))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatarView
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.headline)
                    if info?.verifiedParent == true {
                        Badge(text: "Verified parent", color: .babyPassPink)
                    }
                }

                if let year = info?.joinedYear {
                    Text("Joined \(year)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Seller")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let stats = statsLine {
                    Text(stats)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .padding(.top, 4)
        .onAppear {
            guard info == nil else { return }
            dataService.fetchSellerInfo(uid: sellerUid, fallbackName: sellerName) { fetched in
                info = fetched
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let urlString = info?.profilePhotoURL,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure, .empty:
                    initialAvatar
                @unknown default:
                    initialAvatar
                }
            }
        } else {
            initialAvatar
        }
    }
}

// MARK: - Pickup Row

struct PickupRow: View {
    let listing: Listing

    private var label: String {
        if let location = listing.locationText, !location.isEmpty {
            return "📍 \(location) · Local pickup"
        }
        return "📍 Local pickup"
    }

    var body: some View {
        Text(label)
            .font(.subheadline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

// MARK: - Listed Ago Caption

struct ListedAgoCaption: View {
    let createdAt: Date

    private var text: String {
        let now = Date()
        if now.timeIntervalSince(createdAt) < 60 {
            return "Just listed"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Listed \(formatter.localizedString(for: createdAt, relativeTo: now))"
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

// MARK: - More From Seller Rail

struct MoreFromSellerRail: View {
    let sellerUid: String
    let sellerName: String
    let excludingId: String?

    @EnvironmentObject var dataService: DataService
    @State private var listings: [Listing] = []
    @State private var didLoad = false
    @State private var selectedListing: Listing? = nil

    var body: some View {
        if listings.isEmpty {
            Color.clear
                .frame(height: 0)
                .onAppear(perform: loadIfNeeded)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("More from \(sellerName)")
                    .font(.headline)
                    .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(listings) { item in
                            Button {
                                selectedListing = item
                            } label: {
                                MoreFromSellerCard(listing: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .sheet(item: $selectedListing) { item in
                NavigationStack {
                    ListingDetailView(listing: item)
                }
            }
        }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        dataService.fetchListingsBySeller(uid: sellerUid, excludingId: excludingId) { results in
            listings = results
        }
    }
}

private struct MoreFromSellerCard: View {
    let listing: Listing

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [listing.category.gradientStart, listing.category.gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(listing.category.emoji)
                .font(.system(size: 36))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let first = listing.photoURLs.first, let url = URL(string: first) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure, .empty:
                                placeholder
                            @unknown default:
                                placeholder
                            }
                        }
                    } else {
                        placeholder
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(listing.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)

            Text("$\(Int(listing.price))")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(width: 130)
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
}

#Preview {
    NavigationStack {
        ListingDetailView(listing: Listing(
            id: "preview",
            sellerUid: "preview",
            sellerName: "Emma R.",
            title: "Graco 4Ever Convertible Car Seat",
            price: 120,
            originalPrice: 299,
            category: .gear,
            condition: .likeNew,
            description: "Used for 8 months. No accidents. Cleaned thoroughly.",
            photoURLs: [],
            latitude: 37.4419,
            longitude: -122.1430,
            status: .active,
            createdAt: Date(),
            viewCount: 45
        ))
            .environmentObject(AuthService())
            .environmentObject(DataService())
    }
}
