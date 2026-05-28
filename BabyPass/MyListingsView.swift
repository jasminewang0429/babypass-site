import SwiftUI
import FirebaseAuth

struct MyListingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @State private var listings: [Listing] = []
    @State private var isLoading = true
    @State private var selectedListing: Listing? = nil

    var activeListings: [Listing] {
        listings.filter { $0.status == .active }
    }

    var pendingListings: [Listing] {
        listings.filter { $0.status == .pending }
    }

    var soldListings: [Listing] {
        listings.filter { $0.status == .sold }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading your listings...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if listings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tag.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No listings yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Items you post for sale will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !activeListings.isEmpty {
                            sectionHeader("Available", color: .green)

                            ForEach(activeListings) { listing in
                                MyListingRow(listing: listing, onTap: {
                                    selectedListing = listing
                                }, onStatusChange: { newStatus in
                                    updateStatus(listing, to: newStatus)
                                }, onDelete: {
                                    deleteListing(listing)
                                })
                                .padding(.horizontal, 16)
                            }
                        }

                        if !pendingListings.isEmpty {
                            sectionHeader("Pending Pickup", color: .orange)

                            ForEach(pendingListings) { listing in
                                MyListingRow(listing: listing, onTap: {
                                    selectedListing = listing
                                }, onStatusChange: { newStatus in
                                    updateStatus(listing, to: newStatus)
                                }, onDelete: {
                                    deleteListing(listing)
                                })
                                .padding(.horizontal, 16)
                            }
                        }

                        if !soldListings.isEmpty {
                            sectionHeader("Sold", color: .secondary)

                            ForEach(soldListings) { listing in
                                MyListingRow(listing: listing, onTap: {
                                    selectedListing = listing
                                }, onStatusChange: { newStatus in
                                    updateStatus(listing, to: newStatus)
                                }, onDelete: {
                                    deleteListing(listing)
                                })
                                .opacity(0.6)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("My Listings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let uid = Auth.auth().currentUser?.uid,
               let storefrontURL = URL(string: "https://babypass-49b45.web.app/s/\(uid)") {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(
                        item: storefrontURL,
                        subject: Text("My listings on BabyPass"),
                        message: Text("Check out what I'm selling on BabyPass!")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            loadListings()
        }
        .sheet(item: $selectedListing) { listing in
            NavigationStack {
                ListingDetailView(listing: listing)
                    .environmentObject(authService)
                    .environmentObject(dataService)
            }
        }
    }

    private func sectionHeader(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func loadListings() {
        isLoading = true
        dataService.fetchMyListings { result in
            listings = result
            isLoading = false
        }
    }

    private func updateStatus(_ listing: Listing, to newStatus: Listing.ListingStatus) {
        guard let id = listing.id else { return }
        dataService.updateListingStatus(listingId: id, status: newStatus) { success in
            if success {
                loadListings()
            }
        }
    }

    private func deleteListing(_ listing: Listing) {
        guard let id = listing.id else { return }
        dataService.deleteListing(listingId: id) { success in
            if success {
                listings.removeAll { $0.id == id }
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: Listing.ListingStatus

    private var badgeColor: Color {
        switch status {
        case .active: return .green
        case .pending: return .orange
        case .sold: return .red
        case .removed: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.icon)
                .font(.system(size: 9))
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.12))
        .cornerRadius(5)
    }
}

// MARK: - My Listing Row

struct MyListingRow: View {
    let listing: Listing
    let onTap: () -> Void
    let onStatusChange: (Listing.ListingStatus) -> Void
    let onDelete: () -> Void

    private var thumbnailPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [listing.category.gradientStart, listing.category.gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(listing.category.emoji)
                .font(.title2)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tappable content area (thumbnail + info)
            Button {
                onTap()
            } label: {
                HStack(spacing: 12) {
                    // Thumbnail — show photo if available
                    ZStack {
                        if let firstPhoto = listing.photoURLs.first, let url = URL(string: firstPhoto) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    thumbnailPlaceholder
                                }
                            }
                        } else {
                            thumbnailPlaceholder
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.primary)

                        Text("$\(Int(listing.price))")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        HStack(spacing: 6) {
                            StatusBadge(status: listing.status)

                            Text("·")
                                .foregroundColor(.secondary)

                            Text("\(listing.viewCount) views")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Actions menu — separate from the tap area
            Menu {
                // Status change options
                ForEach(Listing.ListingStatus.sellerOptions, id: \.self) { status in
                    if status != listing.status {
                        Button {
                            onStatusChange(status)
                        } label: {
                            Label("Mark as \(status.displayName)", systemImage: status.icon)
                        }
                    }
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }
}

#Preview {
    NavigationStack {
        MyListingsView()
            .environmentObject(AuthService())
            .environmentObject(DataService())
    }
}
