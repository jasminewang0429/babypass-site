import SwiftUI

struct SavedItemsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var dataService: DataService
    @State private var savedListings: [Listing] = []
    @State private var isLoading = true
    @State private var selectedListing: Listing? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading saved items...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if savedListings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No saved items")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Tap the heart on any listing to save it here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(savedListings) { listing in
                            ListingCard(listing: listing)
                                .onTapGesture {
                                    selectedListing = listing
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Saved Items")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSavedItems()
        }
        .sheet(item: $selectedListing) { listing in
            NavigationStack {
                ListingDetailView(listing: listing)
                    .environmentObject(authService)
                    .environmentObject(dataService)
            }
        }
    }

    private func loadSavedItems() {
        isLoading = true
        dataService.fetchSavedListings { result in
            savedListings = result
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        SavedItemsView()
            .environmentObject(AuthService())
            .environmentObject(DataService())
    }
}
