import SwiftUI
import MapKit
import CoreLocation

struct MapListingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.4419, longitude: -122.1430),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var selectedListing: Listing? = nil
    @State private var showDetail: Listing? = nil
    @State private var showSearchSheet = false
    @State private var searchText = ""

    private var activeListings: [Listing] {
        dataService.listings
    }

    // Distance reference: prefer the location entered on Browse, otherwise live GPS.
    private var referenceLatitude: Double? {
        locationManager.selectedLatitude ?? locationManager.userLatitude
    }
    private var referenceLongitude: Double? {
        locationManager.selectedLongitude ?? locationManager.userLongitude
    }

    private static func cameraRegion(lat: Double, lon: Double, zoom: Double = 0.05) -> MapCameraPosition {
        .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: zoom, longitudeDelta: zoom)
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position, selection: $selectedListing) {
                    ForEach(activeListings) { listing in
                        Annotation(
                            "",
                            coordinate: CLLocationCoordinate2D(
                                latitude: listing.latitude,
                                longitude: listing.longitude
                            ),
                            anchor: .bottom
                        ) {
                            MapPin(listing: listing, isSelected: selectedListing?.id == listing.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedListing = listing
                                    }
                                }
                        }
                        .tag(listing)
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))

                // Bottom sheet
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 8)

                    if let selected = selectedListing {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(selected.category.emoji)
                                    .font(.title2)
                                Text(selected.title)
                                    .font(.headline)
                                    .lineLimit(1)
                            }
                            HStack(spacing: 12) {
                                Text("$\(Int(selected.price))")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.babyPassPink)
                                Text(selected.distanceText(from: referenceLatitude, referenceLongitude))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(selected.sellerName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("View") {
                                    showDetail = selected
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.babyPassPink)
                                .cornerRadius(20)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                    } else {
                        Text("\(activeListings.count) items nearby")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 6)
                    }

                    // Horizontal scroll of cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(activeListings) { listing in
                                MiniListingCard(listing: listing, userLat: referenceLatitude, userLon: referenceLongitude)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedListing = listing
                                            position = .region(MKCoordinateRegion(
                                                center: CLLocationCoordinate2D(
                                                    latitude: listing.latitude,
                                                    longitude: listing.longitude
                                                ),
                                                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                            ))
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 10, y: -4)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSearchSheet = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .onAppear {
                dataService.listenToListings()
                locationManager.requestLocationIfNeeded()
                // Prefer the location entered on the Browse (first) page; fall back to live GPS.
                if let lat = locationManager.selectedLatitude,
                   let lon = locationManager.selectedLongitude {
                    position = Self.cameraRegion(lat: lat, lon: lon)
                } else if let lat = locationManager.userLatitude,
                          let lon = locationManager.userLongitude {
                    position = Self.cameraRegion(lat: lat, lon: lon)
                }
            }
            .onChange(of: locationManager.selectedLatitude) { _, lat in
                if let lat = lat, let lon = locationManager.selectedLongitude {
                    withAnimation { position = Self.cameraRegion(lat: lat, lon: lon) }
                } else if let gpsLat = locationManager.userLatitude,
                          let gpsLon = locationManager.userLongitude {
                    // Selection cleared — snap back to GPS so the map doesn't get stranded.
                    withAnimation { position = Self.cameraRegion(lat: gpsLat, lon: gpsLon) }
                }
            }
            .onChange(of: locationManager.userLatitude) { _, lat in
                // Only re-center on GPS when the user hasn't picked a location.
                guard locationManager.selectedLatitude == nil else { return }
                if let lat = lat, let lon = locationManager.userLongitude {
                    withAnimation { position = Self.cameraRegion(lat: lat, lon: lon) }
                }
            }
            .sheet(item: $showDetail) { listing in
                NavigationStack {
                    ListingDetailView(listing: listing)
                        .environmentObject(authService)
                        .environmentObject(dataService)
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                MapSearchSheet(
                    searchText: $searchText,
                    onSelect: { name, lat, lon in
                        withAnimation {
                            position = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            ))
                        }
                        showSearchSheet = false
                    },
                    onCancel: {
                        showSearchSheet = false
                    }
                )
            }
        }
    }
}

// MARK: - Map Pin

struct MapPin: View {
    let listing: Listing
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("$\(Int(listing.price))")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? Color.blue : Color.babyPassPink)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)

            Triangle()
                .fill(isSelected ? Color.blue : Color.babyPassPink)
                .frame(width: 10, height: 5)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Mini Listing Card

struct MiniListingCard: View {
    let listing: Listing
    var userLat: Double? = nil
    var userLon: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(listing.category.emoji)
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)

            Text("$\(Int(listing.price))")
                .font(.headline)
                .fontWeight(.bold)

            Text(listing.distanceText(from: userLat, userLon))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 110)
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Map Search Sheet

struct MapSearchSheet: View {
    @Binding var searchText: String
    let onSelect: (String, Double, Double) -> Void
    let onCancel: () -> Void

    @State private var results: [(name: String, lat: Double, lon: Double)] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search a place, city, or zip code", text: $searchText)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .onSubmit { searchPlace() }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            results = []
                            hasSearched = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Button {
                    searchPlace()
                } label: {
                    Text("Search")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(searchText.isEmpty ? Color.gray : Color.babyPassPink)
                        .cornerRadius(10)
                }
                .disabled(searchText.isEmpty || isSearching)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if isSearching {
                    ProgressView("Searching...")
                        .padding(.top, 40)
                    Spacer()
                } else if results.isEmpty && hasSearched {
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    Spacer()
                } else {
                    List(results.indices, id: \.self) { index in
                        Button {
                            let result = results[index]
                            onSelect(result.name, result.lat, result.lon)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.babyPassPink)
                                    .font(.title3)
                                Text(results[index].name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray3))
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }

    private func searchPlace() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        hasSearched = true
        results = []

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchText) { placemarks, error in
            DispatchQueue.main.async {
                isSearching = false
                guard let placemarks = placemarks else { return }

                results = placemarks.compactMap { placemark in
                    guard let location = placemark.location else { return nil }
                    let parts = [placemark.name, placemark.locality, placemark.administrativeArea]
                        .compactMap { $0 }
                    let name = parts.joined(separator: ", ")
                    return (
                        name: name.isEmpty ? searchText : name,
                        lat: location.coordinate.latitude,
                        lon: location.coordinate.longitude
                    )
                }
            }
        }
    }
}

#Preview {
    MapListingsView()
        .environmentObject(AuthService())
        .environmentObject(DataService())
}
