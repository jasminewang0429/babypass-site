import SwiftUI

struct ReportView: View {
    let itemTitle: String
    let onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = ""
    @State private var additionalDetails = ""

    private let reasons = [
        "Inappropriate or offensive content",
        "Spam or misleading listing",
        "Prohibited or unsafe item",
        "Suspected fraud or scam",
        "Harassment or abusive behavior",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Why are you reporting this?")
                        .font(.headline)
                        .padding(.top, 8)

                    Text("Reporting: \(itemTitle)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        ForEach(reasons, id: \.self) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                HStack {
                                    Text(reason)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedReason == reason {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.babyPassPink)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                            }

                            if reason != reasons.last {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Additional details (optional)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextField("Describe the issue...", text: $additionalDetails, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }

                    Button {
                        let fullReason = additionalDetails.isEmpty
                            ? selectedReason
                            : "\(selectedReason): \(additionalDetails)"
                        onSubmit(fullReason)
                    } label: {
                        Text("Submit Report")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(selectedReason.isEmpty ? Color.gray : Color.babyPassPink)
                            .cornerRadius(14)
                    }
                    .disabled(selectedReason.isEmpty)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ReportView(itemTitle: "Test Item") { reason in
        print(reason)
    }
}
