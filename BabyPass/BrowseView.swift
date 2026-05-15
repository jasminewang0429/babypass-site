import SwiftUI
import CoreLocation

struct BrowseView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: Listing.ListingCategory? = nil
    @State private var selectedListing: Listing? = nil
    @State private var showLocationPicker = false
    @State private var locationName = "Nearby"
    @State private var userLatitude: Double? = nil
    @State private var userLongitude: Double? = nil
    @State private var radiusMiles: Double = 25
    @State private var showAvailableOnly = false
    @State private var userPickedLocation = false

    private var filteredListings: [Listing] {
        let source = dataService.listings
        return source.filter { listing in
            let matchesCategory = selectedCategory == nil || listing.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                listing.title.localizedCaseInsensitiveContains(searchText)
            let matchesAvailability = !showAvailableOnly || listing.status == .active
            let matchesLocation: Bool
            if let uLat = userLatitude, let uLon = userLongitude {
                let distance = distanceInMiles(
                    lat1: uLat, lon1: uLon,
                    lat2: listing.latitude, lon2: listing.longitude
                )
                matchesLocation = distance <= radiusMiles
            } else {
                matchesLocation = true
            }
            return matchesCategory && matchesSearch && matchesLocation && matchesAvailability
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Location button
                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(locationName)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.babyPassPink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.babyPassPink.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                    // Category chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryChip(
                                title: "All",
                                emoji: "✨",
                                isSelected: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                            }

                            ForEach(Listing.ListingCategory.allCases, id: \.self) { cat in
                                CategoryChip(
                                    title: cat.rawValue,
                                    emoji: cat.emoji,
                                    isSelected: selectedCategory == cat
                                ) {
                                    selectedCategory = cat
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)

                    // Availability filter
                    HStack {
                        Button {
                            showAvailableOnly.toggle()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: showAvailableOnly ? "checkmark.circle.fill" : "circle")
                                    .font(.subheadline)
                                Text("Available only")
                                    .font(.subheadline)
                            }
                            .foregroundColor(showAvailableOnly ? .babyPassPink : .secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    // Results count
                    if userLatitude != nil {
                        Text("\(filteredListings.count) items within \(Int(radiusMiles)) miles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }

                    // Listings grid
                    if filteredListings.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No listings found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Try changing your filters or check back later")
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredListings) { listing in
                                ListingCard(listing: listing, userLat: userLatitude, userLon: userLongitude)
                                    .onTapGesture {
                                        selectedListing = listing
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Browse")
            .searchable(text: $searchText, prompt: "Search baby gear...")
            .refreshable {
                dataService.listenToListings()
            }
            .onAppear {
                dataService.listenToListings()
                locationManager.requestLocationIfNeeded()
            }
            .onChange(of: locationManager.userLatitude) { _, lat in
                if !userPickedLocation, let lat = lat, let lon = locationManager.userLongitude {
                    userLatitude = lat
                    userLongitude = lon
                    locationName = locationManager.locationName
                }
            }
            .onChange(of: locationManager.locationName) { _, name in
                if !userPickedLocation {
                    locationName = name
                }
            }
            .sheet(item: $selectedListing) { listing in
                NavigationStack {
                    ListingDetailView(listing: listing)
                        .environmentObject(authService)
                        .environmentObject(dataService)
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                BrowseLocationPicker(
                    onSelect: { name, lat, lon, radius in
                        userPickedLocation = true
                        locationName = name
                        userLatitude = lat
                        userLongitude = lon
                        radiusMiles = radius
                        // Share the picked location so the Map tab can auto-center on it.
                        locationManager.setSelectedLocation(name: name, lat: lat, lon: lon)
                        showLocationPicker = false
                    },
                    onClear: {
                        userPickedLocation = false
                        locationName = locationManager.locationName
                        userLatitude = locationManager.userLatitude
                        userLongitude = locationManager.userLongitude
                        locationManager.clearSelectedLocation()
                        showLocationPicker = false
                    },
                    onCancel: {
                        showLocationPicker = false
                    }
                )
            }
        }
    }

    private func distanceInMiles(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let loc1 = CLLocation(latitude: lat1, longitude: lon1)
        let loc2 = CLLocation(latitude: lat2, longitude: lon2)
        return loc1.distance(from: loc2) / 1609.34
    }
}

// MARK: - Browse Location Picker

struct BrowseLocationPicker: View {
    let onSelect: (String, Double, Double, Double) -> Void
    let onClear: () -> Void
    let onCancel: () -> Void

    @State private var zipCode = ""
    @State private var selectedRadius: Double = 10
    @State private var isSearching = false
    @State private var errorText: String? = nil

    private let radiusOptions: [Double] = [5, 10, 25, 50]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Zip code input
                VStack(alignment: .leading, spacing: 6) {
                    Text("ZIP CODE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.3)

                    TextField("Enter zip code", text: $zipCode)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(14)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }

                // Radius picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("SEARCH RADIUS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .tracking(0.3)

                    HStack(spacing: 8) {
                        ForEach(radiusOptions, id: \.self) { radius in
                            Button {
                                selectedRadius = radius
                            } label: {
                                Text("\(Int(radius)) mi")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(selectedRadius == radius ? Color.babyPassPink : Color(.systemGray6))
                                    .foregroundColor(selectedRadius == radius ? .white : .primary)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }

                if let error = errorText {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // Search button
                Button {
                    searchZipCode()
                } label: {
                    Group {
                        if isSearching {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Search This Area")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(zipCode.isEmpty ? Color.gray : Color.babyPassPink)
                    .cornerRadius(14)
                }
                .disabled(zipCode.isEmpty || isSearching)

                // Clear location
                Button {
                    onClear()
                } label: {
                    Text("Show All Listings")
                        .font(.subheadline)
                        .foregroundColor(.babyPassPink)
                }

                Spacer()
            }
            .padding(16)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Set Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }

    private func searchZipCode() {
        guard !zipCode.isEmpty else { return }
        isSearching = true
        errorText = nil

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(zipCode) { placemarks, error in
            DispatchQueue.main.async {
                isSearching = false

                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    errorText = "Could not find that zip code. Please try again."
                    return
                }

                let name = [placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                let displayName = name.isEmpty ? zipCode : "\(name) (\(zipCode))"

                onSelect(displayName, location.coordinate.latitude, location.coordinate.longitude, selectedRadius)
            }
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.babyPassPink : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Listing Card

struct ListingCard: View {
    let listing: Listing
    var userLat: Double? = nil
    var userLon: Double? = nil

    private var listingPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [listing.category.gradientStart, listing.category.gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(listing.category.emoji)
                .font(.system(size: 48))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image or placeholder
            GeometryReader { geo in
                ZStack {
                    if let firstPhoto = listing.photoURLs.first, let url = URL(string: firstPhoto) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.width)
                            case .failure(_):
                                listingPlaceholder
                            case .empty:
                                ZStack {
                                    listingPlaceholder
                                    ProgressView()
                                }
                            @unknown default:
                                listingPlaceholder
                            }
                        }
                    } else {
                        listingPlaceholder
                    }

                    // Overlay badges
                    VStack {
                        HStack {
                            // Status badge (only for non-active)
                            if listing.status == .pending {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 8))
                                    Text("Pending")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange)
                                .cornerRadius(6)
                            }

                            Spacer()

                            Text(listing.distanceText(from: userLat, userLon))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.55))
                                .cornerRadius(6)
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(height: 34, alignment: .top)

                Text("$\(Int(listing.price))")
                    .font(.headline)
                    .fontWeight(.bold)

                Text("\(listing.condition.rawValue) · \(listing.sellerName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

// MARK: - Color & Gradient Helpers

extension Color {
    static let babyPassPink = Color(red: 1.0, green: 0.216, blue: 0.373)
}

extension Listing.ListingCategory {
    var gradientStart: Color {
        switch self {
        case .gear: return Color(red: 1.0, green: 0.85, blue: 0.85)
        case .toys: return Color(red: 1.0, green: 0.93, blue: 0.8)
        case .books: return Color(red: 0.85, green: 0.92, blue: 1.0)
        case .clothes: return Color(red: 0.93, green: 0.85, blue: 1.0)
        case .feeding: return Color(red: 0.85, green: 1.0, blue: 0.9)
        case .bath: return Color(red: 0.85, green: 0.95, blue: 1.0)
        case .nursery: return Color(red: 1.0, green: 0.9, blue: 0.85)
        case .other: return Color(red: 0.92, green: 0.92, blue: 0.92)
        }
    }

    var gradientEnd: Color {
        switch self {
        case .gear: return Color(red: 1.0, green: 0.75, blue: 0.78)
        case .toys: return Color(red: 1.0, green: 0.85, blue: 0.65)
        case .books: return Color(red: 0.75, green: 0.82, blue: 1.0)
        case .clothes: return Color(red: 0.85, green: 0.75, blue: 1.0)
        case .feeding: return Color(red: 0.75, green: 0.95, blue: 0.8)
        case .bath: return Color(red: 0.75, green: 0.88, blue: 1.0)
        case .nursery: return Color(red: 1.0, green: 0.8, blue: 0.7)
        case .other: return Color(red: 0.82, green: 0.82, blue: 0.82)
        }
    }
}

extension Listing {
    func distanceText(from userLat: Double?, _ userLon: Double?) -> String {
        guard let userLat = userLat, let userLon = userLon else {
            return "-- mi"
        }
        let userLoc = CLLocation(latitude: userLat, longitude: userLon)
        let itemLoc = CLLocation(latitude: latitude, longitude: longitude)
        let miles = userLoc.distance(from: itemLoc) / 1609.34
        if miles < 0.1 {
            return "Nearby"
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return "\(Int(miles)) mi"
        }
    }
}

#Preview {
    BrowseView()
        .environmentObject(AuthService())
        .environmentObject(DataService())
}
