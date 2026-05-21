---
name: storekit-2-iap
description: Use when implementing in-app purchases with StoreKit 2 — consumables, subscriptions, restore flow, server-side validation, App Store Server Notifications V2. Triggers: `import StoreKit`, mentions of `Product.products`, `Transaction.updates`, `JWS`, `appAccountToken`, `Restore Purchases`, `Ask to Buy`, refunds, "validate receipt", or any IAP design discussion.
---

# StoreKit 2 IAP patterns

Server-validated currency/entitlement flow that survives Ask-to-Buy, family sharing, refunds, and replay attacks.

## The non-negotiable rule

**Server is the only place currency / entitlements are credited.** Client never increments a balance based on `Transaction` alone — it's trivial to spoof.

Every transaction's JWS goes to a server endpoint that:
1. Verifies the JWS signature against Apple's leaf cert (ES256).
2. Idempotently credits via a transaction-id-keyed ledger (`iap_purchases` table with PK on `transaction_id`).
3. Returns the server-canonical balance to the client.

The client UI updates from the server response, not from the transaction itself.

## Catalog mirroring

- Product IDs (`com.<you>.<app>.heights_1k`, etc.) live in a `Catalog` enum on the client AND in a parallel TS module on the server.
- Both sides know: product ID → quantity / entitlement type / display name fallback.
- `Product.displayPrice` from StoreKit is the source of truth for price strings shown to the user — never hardcode prices in app metadata.

## Storefront wiring

```
@MainActor @Observable final class StoreService {
  private(set) var products: [String: Product] = [:]
  private var updatesTask: Task<Void, Never>?

  func bootstrap() {
    if updatesTask == nil {
      updatesTask = Task.detached(priority: .background) { [weak self] in
        for await result in Transaction.updates {
          await self?.handleTransactionResult(result)
        }
      }
    }
    Task { await loadProducts() }
  }
}
```

- Long-lived `Transaction.updates` listener task started at app launch handles Ask-to-Buy approvals, family sharing transactions, and store-side replays.
- Bootstrap once in `App.init`. The task lives the lifetime of the process.

## Purchase flow

1. User taps a bundle → `StoreService.purchase(bundle)`.
2. Look up the cached `Product`.
3. Bind purchase to the user with `Product.PurchaseOption.appAccountToken(uuid)` so the server can refuse a transaction "belonging to" a different account.
4. `try await product.purchase(options: …)`.
5. On `.success(let verificationResult)`: extract `transaction.jwsRepresentation` → forward to server.
6. After server credit succeeds: `await transaction.finish()`.
7. UI reads the server-returned balance; never the local transaction.

## Restore Purchases

- A "Restore Purchases" button is **mandatory** for any IAP storefront — Apple rejects without one.
- Implementation: `try await AppStore.sync()` then re-iterate `Transaction.currentEntitlements`, forwarding any unfinished JWS to the server.
- For consumables, this surfaces unfinished transactions even though "currentEntitlements" is non-consumable-flavored.

## App Store Server Notifications V2

- Subscribe via App Store Connect → App → App Information → App Store Server Notifications → Production / Sandbox URL.
- Webhook target receives a signed JWS payload — **the request body is the auth**. If on Supabase, set `verify_jwt = false` in `supabase/config.toml` for that edge function (don't expect a Supabase auth bearer; Apple isn't sending one).
- Decode the JWS, check `notificationType`:
  - `REFUND` / `REVOKE` → revoke the ledger row, decrement balance, push a UX nudge.
  - `CONSUMPTION_REQUEST` → reply within 12h with consumption data (rare for one-shot consumables; mandatory for subscriptions).
  - `DID_RENEW` / `EXPIRED` → for subscriptions, update entitlement expiry.
- Idempotency keyed on `transaction_id` so duplicate notifications (which DO happen) don't double-process.

## Apple paperwork that blocks IAP

Before submitting any IAP for review:
- [ ] Paid Apple Developer Program enrolled.
- [ ] **Paid Applications Agreement** signed in App Store Connect → Agreements, Tax, and Banking. (Symptom when forgotten: IAPs are stuck "Waiting for Review" forever.)
- [ ] Tax forms (W-9 US, W-8BEN non-US individual).
- [ ] Banking info — where revenue lands.
- [ ] Each IAP product created with the exact product ID the catalog uses, "Cleared for Sale" toggled.

## Common rejections / pitfalls

- **IAP for digital goods routed through Stripe** (Guideline 3.1.1) → reject. Digital goods MUST use IAP. Physical goods, real-world services, and B2B subscriptions can use other processors.
- **Restore Purchases button missing** → reject.
- **Subscription disclosure missing** — price/period/auto-renewal language must appear adjacent to the purchase button AND in the app description.
- **Consumables without server validation** → may pass review but get cheated post-launch. Don't.
- **Sandbox tester confusion** — "no products available" usually means: agreement not signed, product not "Cleared for Sale", or device signed into a real Apple ID instead of a sandbox tester (Settings → App Store → Sandbox Account on iOS 17+).
- **`appAccountToken` mismatch** — if a user purchases on Account A, signs out, signs in as Account B, then restores, the server should refuse to credit the new account. Use `appAccountToken` as the server-side guard.

## Test approach

- Unit-test `StoreService` against a stub `Product`-equivalent + a stub `BackendClient`.
- StoreKit Configuration files (`.storekit`) for sim/device testing without sandbox accounts — Edit Scheme → Run → StoreKit Configuration.
- Sandbox tester accounts (App Store Connect → Users and Access → Sandbox Testers) for real network paths.
