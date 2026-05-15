import SwiftUI
import MapKit

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
    @ObservedObject private var locationManager = LocationManager.shared

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
                    DetailInfoSection(listing: listing, userLat: locationManager.userLatitude, userLon: locationManager.userLongitude)
                    DetailSellerCard(sellerName: listing.sellerName)
                    DetailMiniMap(listing: listing, userLat: locationManager.userLatitude, userLon: locationManager.userLongitude)
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
    var userLat: Double? = nil
    var userLon: Double? = nil

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
                Badge(text: listing.distanceText(from: userLat, userLon), color: .orange)
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
    let sellerName: String

    var body: some View {
        HStack(spacing: 12) {
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
                    Text(String(sellerName.prefix(1)))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(sellerName)
                    .font(.headline)
                Text("Seller")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .padding(.top, 4)
    }
}

// MARK: - Detail Mini Map

struct DetailMiniMap: View {
    let listing: Listing
    var userLat: Double? = nil
    var userLon: Double? = nil

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: listing.latitude, longitude: listing.longitude)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker(listing.title, coordinate: coordinate)
                    .tint(.red)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .allowsHitTesting(false)

            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                Text("\(listing.distanceText(from: userLat, userLon)) away · Local pickup")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial)
            .cornerRadius(8)
            .padding(10)
        }
        .padding(.top, 4)
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
        ListingDetailView(listing: SampleData.listings[0])
            .environmentObject(AuthService())
            .environmentObject(DataService())
    }
}
