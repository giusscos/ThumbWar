# In-app purchases setup

Premium accessories are sold as **non-consumable** in-app purchases with
StoreKit 2 (`ThumbWar/Services/Store.swift`). The App Store is the source of
truth: on every launch, and after **Settings → Restore Purchases**, the game
syncs its premium items to the player's current entitlements, so a refunded or
revoked purchase takes the item away again.

## App Store Connect

Create these in **App Store Connect → your app → Monetization → In-App
Purchases** (the app record must use the bundle ID `com.giusscos.ThumbestWar`).
All are **Non-Consumable**. The product IDs must match
`Store.productID(for:)`, which is `com.giusscos.ThumbestWar.item.<accessory id>`
with the ids from `ThumbWar/Game/Accessories.swift`.

| Product ID | Reference name | Display name | Price (USD) | Description |
| --- | --- | --- | --- | --- |
| `com.giusscos.ThumbestWar.item.crown` | Item: Crown | Crown | $1.99 | A shiny golden crown for royal thumbs. |
| `com.giusscos.ThumbestWar.item.unicorn` | Item: Unicorn | Unicorn | $1.99 | A magical unicorn horn and ears. |
| `com.giusscos.ThumbestWar.item.propeller` | Item: Propeller | Propeller | $0.99 | A spinning propeller beanie. |
| `com.giusscos.ThumbestWar.item.pumpkin` | Item: Pumpkin | Pumpkin | $0.99 | A carved jack-o'-lantern for Halloween. |
| `com.giusscos.ThumbestWar.item.frankenstein` | Item: Monster | Monster | $1.99 | Bolts, stitches and a flat top. It's alive! |
| `com.giusscos.ThumbestWar.item.spider` | Item: Spider | Spider | $0.99 | A creepy crawly spider for Halloween. |

For each one you also need:

- **Availability**: all territories (or the ones the app ships in). Prices for
  other storefronts follow the US base price automatically.
- **Review information**: a screenshot of the item in the Locker shop
  (try it on, then capture the "Buy" bar) and a review note such as "Open
  Locker, tap a ★ item, tap Buy."
- **Family Sharing**: off for now. It can be turned on later, but once it's on
  for a product it can't be turned off again.

The first in-app purchases have to be submitted together with an app version:
attach them in the version's **In-App Purchases and Subscriptions** section.

## Adding new premium items

1. Add the accessory to `Accessory.all` with `unlock: .premium`.
2. Create a non-consumable with ID `com.giusscos.ThumbestWar.item.<id>` in App Store
   Connect, and add the same product to `ThumbWar.storekit`.

Nothing else in the code needs to change.

## Testing

- **Simulator / Xcode**: the shared `ThumbWar` scheme's Run action uses
  `ThumbWar.storekit` (repo root), so purchases work locally without App Store
  Connect. Use **Debug → StoreKit → Manage Transactions** to refund or delete
  purchases; a refund removes the item right away, and a deleted transaction
  removes it on the next launch.
- **Device / TestFlight**: uses the sandbox and the products in App Store
  Connect. Sign in with a sandbox account under **Settings → Developer**
  (device) to buy without being charged.
