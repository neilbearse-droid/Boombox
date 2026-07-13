import StoreKit
import SwiftUI

/// Optional support, parent-facing only. Nothing in the app is paywalled;
/// this screen exists for families who want to keep the app cared for.
struct TipJarView: View {
    @State private var store = TipJarStore()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Boombox is free for every family.")
                        .font(.headline)
                    Text("Every feature, forever, no strings. If it's brought some music into your house and you'd like to help keep it cared for, a tip does exactly that. Either way — enjoy the music.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if store.didJustTip {
                Section {
                    Label {
                        Text("Thank you! That genuinely helps.")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                    }
                }
            }

            Section {
                if store.loadFailed {
                    Text("Tips aren't available right now.")
                        .foregroundStyle(.secondary)
                } else if store.products.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Loading…").foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(store.products, id: \.id) { product in
                        Button {
                            Task { await store.tip(product) }
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(store.isPurchasing)
                    }
                }
            } footer: {
                Text("Tips are one-time and unlock nothing — everything is already yours.")
            }
        }
        .navigationTitle("Tip Jar")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load()
        }
        .task {
            await store.observeTransactions()
        }
    }
}
