# Tip Jar — Implementation Plan

## Goal

Let users leave an optional tip via in-app purchase. Surface it in the Settings tab under a dedicated "Support the App" section. Keep it low-friction: a single sheet showing 3–4 tip amounts with a clear thank-you.

---

## Prerequisite Steps (Done Before Writing Code)

### App Store Connect

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com) → your app → **Monetization** → **In-App Purchases** → **+**.
2. Create one product per tip amount. Use **Consumable** type (users can tip multiple times; consumable IAPs are not restorable and don't need to persist across reinstalls).
3. Suggested product IDs and tiers:

   | Product ID | Price |
   |------------|-------|
   | `com.yourapp.tip.small` | $0.99 |
   | `com.yourapp.tip.medium` | $2.99 |
   | `com.yourapp.tip.large` | $4.99 |
   | `com.yourapp.tip.xlarge` | $9.99 |

   Use whatever bundle ID prefix matches your app (`Bundle.main.bundleIdentifier`).

4. For each product: fill in **Reference Name** (internal only), add a **Display Name** ("Small Tip"), add a **Description** ("A small thank-you for the app"), set the **Price**.
5. Submit each product for review. Products can be reviewed independently of an app update, but must be in "Ready to Submit" or "Approved" state before they are purchasable in production. They are immediately available in the sandbox.
6. You do **not** need to set up a server or webhook for consumable tips — client-side transaction verification is sufficient.

### Xcode

No new capabilities needed. StoreKit 2 is part of the standard SDK. You do need to create a **StoreKit Configuration File** for local testing:

1. File → New → File → **StoreKit Configuration File** → name it `StoreKitConfig.storekit`.
2. Add your 4 consumable products to it, matching the product IDs from App Store Connect.
3. In the scheme editor: Run → Options → **StoreKit Configuration** → select the file.

This lets you test purchases in Simulator without App Store Connect approval.

---

## Architecture

### New file: `Services/TipService.swift`

```swift
import StoreKit
import Foundation

@MainActor
final class TipService: ObservableObject {
    static let shared = TipService()

    @Published var products: [Product] = []
    @Published var purchaseState: PurchaseState = .idle
    @Published var lastPurchasedProductID: String?

    enum PurchaseState {
        case idle
        case purchasing
        case success
        case failed(Error)
    }

    private let productIDs = [
        "com.yourapp.tip.small",
        "com.yourapp.tip.medium",
        "com.yourapp.tip.large",
        "com.yourapp.tip.xlarge"
    ]

    private init() {}

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            AppLogger.service.error("TipService: Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                lastPurchasedProductID = transaction.productID
                await transaction.finish()
                purchaseState = .success
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            AppLogger.service.error("TipService: Purchase failed: \(error)")
            purchaseState = .failed(error)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
```

### New file: `Views/TipJarView.swift`

Present this as a sheet from `SettingsView`. It should:

- Show a brief "Support the App" headline and a one-line description
- Display the 4 tip buttons in a vertical list or 2×2 grid, each showing the formatted price
- Show a loading spinner while `products` is empty (network fetch)
- Show a "Thank you!" confirmation after a successful purchase with a haptic
- Disable the buttons and show a spinner during `purchasing` state
- Handle the `failed` state with a short error message (don't expose raw error strings to users)
- Accessibility: each button needs `.accessibilityLabel("Tip \(product.displayPrice)")` and `.accessibilityHint("One-time purchase, non-refundable")`

```swift
import SwiftUI
import StoreKit

struct TipJarView: View {
    @StateObject private var tipService = TipService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            // ... product list, purchase buttons, state handling
        }
        .task {
            await tipService.loadProducts()
        }
    }
}
```

---

## Changes to Existing Files

### `SettingsView.swift`

Add a new section above "About":

```swift
Section(header: Text("Support")) {
    Button(action: { showingTipJar = true }) {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(.pink)
            Text("Leave a Tip")
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .accessibilityLabel("Leave a Tip")
    .accessibilityHint("Opens the tip jar to support app development")
}
```

Add `@State private var showingTipJar = false` and a `.sheet(isPresented: $showingTipJar) { TipJarView() }` modifier.

---

## Purchase Flow (User's Perspective)

1. User taps "Leave a Tip" in Settings.
2. Sheet opens showing tip amounts with App Store prices.
3. User taps an amount → system shows Apple's standard payment confirmation dialog.
4. On confirmation → "Thank you!" screen with brief animation and haptic.
5. Sheet dismisses (or user can tip again).

---

## Transaction Handling Notes

- Consumable IAPs do **not** need `Transaction.currentEntitlements` or restoration. Each purchase is independent.
- Always call `await transaction.finish()` after handling a successful purchase — this is required by StoreKit 2 to remove the transaction from the queue.
- Do not implement a "Restore Purchases" button for a tip-only IAP. Consumables can't be restored and Apple does not require it. (Non-consumable IAPs require it.)
- Apple takes 30% (or 15% if you qualify for the Small Business Program — check your App Store Connect account).

---

## Pricing & Currency

StoreKit automatically formats prices in the user's local currency and locale (`product.displayPrice` returns the correct string). Never hardcode "$0.99" in the UI — always use `product.displayPrice`.

---

## Testing

| Scenario | How to Test |
|----------|-------------|
| Products load | Run in Simulator with StoreKit config file |
| Successful purchase | Use Simulator sandbox — confirm "Thank you" appears, haptic fires |
| User cancels | Tap Cancel on payment sheet — confirm idle state, no error shown |
| Network failure during product load | Disable network in Simulator → confirm loading spinner with graceful fallback message |
| Production | Use sandbox tester account on physical device (App Store Connect → Users → Sandbox Testers) |

---

## App Store Review Considerations

- Tips are allowed under App Store guidelines — users voluntarily support developers.
- Do **not** require a tip to unlock features or content (that would make them non-consumable and need different review handling).
- The "Leave a Tip" button placement in Settings is appropriate. Apple reviewers look for tips to be clearly voluntary.
- Apple may ask for a review screenshot — have one ready with the tip sheet open.

---

## Estimated Effort

| Phase | Work |
|-------|------|
| App Store Connect product setup | 30 min |
| StoreKit config file for Simulator | 15 min |
| `TipService.swift` | 2 hours |
| `TipJarView.swift` (UI + accessibility) | 2–3 hours |
| Wire into `SettingsView` | 30 min |
| Testing (Simulator + device) | 2 hours |
| **Total** | **~1 day** |
