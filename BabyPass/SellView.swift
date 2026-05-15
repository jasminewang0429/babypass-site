import SwiftUI
import PhotosUI
import CoreLocation

struct SellView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @State private var title = ""
    @State private var price = ""
    @State private var originalPrice = ""
    @State private var category: Listing.ListingCategory = .toys
    @State private var condition: Listing.ItemCondition = .good
    @State private var description = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var showPostedAlert = false
    @State private var isPosting = false
    @State private var showCamera = false
    @State private var showPhotoMenu = false
    @State private var showLibraryPicker = false

    // Location
    @State private var locationText = ""
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var showLocationSheet = false
    @State private var locationSearchText = ""
    @State private var isSearchingLocation = false

    var isFormValid: Bool {
        !title.isEmpty && !price.isEmpty && !locationText.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Photos section
                    PhotoSectionView(
                        photoImages: $photoImages,
                        selectedPhotos: $selectedPhotos,
                        showPhotoMenu: $showPhotoMenu,
                        showLibraryPicker: $showLibraryPicker
                    )

                    // Form fields
                    FormField(label: "TITLE") {
                        TextField("e.g. Graco Car Seat", text: $title)
                            .font(.body)
                    }

                    FormField(label: "PRICE") {
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0", text: $price)
                                .keyboardType(.decimalPad)
                        }
                        .font(.body)
                    }

                    FormField(label: "ORIGINAL PRICE (OPTIONAL)") {
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("Retail price", text: $originalPrice)
                                .keyboardType(.decimalPad)
                        }
                        .font(.body)
                    }

                    FormField(label: "CATEGORY") {
                        Picker("Category", selection: $category) {
                            ForEach(Listing.ListingCategory.allCases, id: \.self) { cat in
                                Text("\(cat.emoji) \(cat.rawValue)").tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    FormField(label: "CONDITION") {
                        Picker("Condition", selection: $condition) {
                            ForEach(Listing.ItemCondition.allCases, id: \.self) { cond in
                                Text(cond.rawValue).tag(cond)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    FormField(label: "DESCRIPTION") {
                        TextField("Tell other parents about your item...", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                            .font(.body)
                    }

                    // Pickup location
                    FormField(label: "PICKUP LOCATION") {
                        Button {
                            locationSearchText = locationText
                            showLocationSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.babyPassPink)
                                if locationText.isEmpty {
                                    Text("Tap to set location")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(locationText)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Text(locationText.isEmpty ? "Set" : "Change")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    // Post button
                    Button {
                        postItem()
                    } label: {
                        Group {
                            if isPosting {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Posting...")
                                        .fontWeight(.semibold)
                                }
                            } else {
                                Text("Post Item")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid && !isPosting ? Color.babyPassPink : Color.gray)
                        .cornerRadius(14)
                    }
                    .disabled(!isFormValid || isPosting)
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Post an Item")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Item Posted!", isPresented: $showPostedAlert) {
                Button("OK") {
                    resetForm()
                    selectedTab = 0 // Switch to Browse tab
                }
            } message: {
                Text("Your item is now live and visible to nearby parents.")
            }
            .sheet(isPresented: $showLocationSheet) {
                LocationPickerSheet(
                    searchText: $locationSearchText,
                    onSelect: { name, lat, lon in
                        locationText = name
                        latitude = lat
                        longitude = lon
                        showLocationSheet = false
                    },
                    onCancel: {
                        showLocationSheet = false
                    }
                )
            }
            .confirmationDialog("Add Photo", isPresented: $showPhotoMenu) {
                Button("Take Photo") {
                    showCamera = true
                }
                Button("Choose from Library") {
                    showLibraryPicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if photoImages.count < 8 {
                        photoImages.append(image)
                    }
                    showCamera = false
                }
                .ignoresSafeArea()
            }
        }
    }

    private func postItem() {
        guard let priceValue = Double(price) else { return }
        let origPrice = Double(originalPrice)

        isPosting = true
        dataService.postListing(
            title: title,
            price: priceValue,
            originalPrice: origPrice,
            category: category,
            condition: condition,
            description: description,
            photos: photoImages,
            latitude: latitude,
            longitude: longitude
        ) { success in
            isPosting = false
            if success {
                showPostedAlert = true
            }
        }
    }

    private func resetForm() {
        title = ""
        price = ""
        originalPrice = ""
        description = ""
        locationText = ""
        latitude = 0
        longitude = 0
        selectedPhotos = []
        photoImages = []
    }
}

// MARK: - Location Picker Sheet

struct LocationPickerSheet: View {
    @Binding var searchText: String
    let onSelect: (String, Double, Double) -> Void
    let onCancel: () -> Void

    @State private var results: [(name: String, lat: Double, lon: Double)] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("City, neighborhood, or zip code", text: $searchText)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .onSubmit {
                            searchLocation()
                        }
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

                // Search button
                Button {
                    searchLocation()
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
                        Text("Try a different city or zip code")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
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
            .navigationTitle("Pickup Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }

    private func searchLocation() {
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
                    let name = [placemark.locality, placemark.administrativeArea]
                        .compactMap { $0 }
                        .joined(separator: ", ")
                    return (
                        name: name.isEmpty ? (placemark.name ?? searchText) : name,
                        lat: location.coordinate.latitude,
                        lon: location.coordinate.longitude
                    )
                }
            }
        }
    }
}

// MARK: - Photo Section

struct PhotoSectionView: View {
    @Binding var photoImages: [UIImage]
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var showPhotoMenu: Bool
    @Binding var showLibraryPicker: Bool

    var body: some View {
        Group {
            if photoImages.isEmpty {
                emptyState
            } else {
                photoStrip
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        if photoImages.count < 8 {
                            photoImages.append(img)
                        }
                    }
                }
                selectedPhotos = []
            }
        }
        .photosPicker(
            isPresented: $showLibraryPicker,
            selection: $selectedPhotos,
            maxSelectionCount: max(1, 8 - photoImages.count),
            matching: .images
        )
    }

    private var emptyState: some View {
        Button {
            showPhotoMenu = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                Text("Add up to 8 photos")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Tap to take or choose photos")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(Color(.systemGray4))
            )
            .cornerRadius(14)
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photoImages.indices, id: \.self) { i in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: photoImages[i])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            photoImages.remove(at: i)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: -4, y: 4)
                    }
                }

                if photoImages.count < 8 {
                    Button {
                        showPhotoMenu = true
                    } label: {
                        VStack {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 120, height: 120)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

// MARK: - Form Field

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .tracking(0.3)

            content
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    SellView(selectedTab: .constant(2))
        .environmentObject(AuthService())
        .environmentObject(DataService())
}
