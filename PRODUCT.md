# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Floor cashiers and assigned staff at Pyx Food retail / walk-in points of sale. They scan bottles and pouches, take cash or AR, and print thermal receipts under shop lighting, usually one-handed with a Bluetooth ESC/POS printer nearby.

## Product Purpose

Mobile POS terminal that sells finished honey and department stock, syncs sales to RTS / Pyx Tracker, and prints receipts on a personal thermal printer without watermarks. Success is a fast, reliable sell → print → done loop with correct inventory and refunds that restock packaging/finished inventory.

## Positioning

A staff-assigned mobile POS with the same checkout/receipt language as the RTS web POS, plus a built-in thermal print engine (Bluetooth / USB / TCP) — not a generic printer utility and not a browser wrapper.

## Operating Context

Android phones/tablets; Bluetooth KJ-5802H-class printers; RTS API (`pos_staff_login`, unified checkout, history, refund); barcodes for unique bottles and SKUs; shop-floor interruptions (reprints, AR debtors, partial connectivity).

## Capabilities and Constraints

- Login for assigned Mobile POS staff (employee ID only).
- Sell, AR credit, sales history (reprint / full refund), printer connection, settings.
- Checkout discounts 0% / 10% / 20%; seller name from logged-in staff.
- Receipt layout matches web POS (Pyx logo, Buyer/Seller, line items, totals).
- Must remain task-first and readable outdoors/indoors; no decorative chrome that slows scanning.

## Brand Commitments

- Pyx Food / Pyx Tracker product family.
- Official POS seal logo (launcher icon + login mark): `assets/pyx_pos_logo.png` / `assets/pyx_pos_mark.png`.
- Receipt mark: `assets/pyxfoodpr.png`.
- Seal forest green (`#205010`) as primary; RTS gold `#C8900A` as secondary commerce accent when needed.
- Mobile POS sign-in: employee ID only; executives or assigned Mobile POS staff only.

## Evidence on Hand

- Flutter app in `lib/` with MethodChannel print bridge.
- Receipt assets and formatters under `lib/src/pos/`.
- RTS backend at `C:\xampp\htdocs\rts` (not shipped inside this APK).

## Product Principles

1. Task speed over spectacle — every screen earns its keep in a sell or support job.
2. Same language as RTS web POS (buyer, seller, receipt numbers, discounts).
3. Honest state: connected printer, signed-in staff, errors that name the fix.
4. Restock and money paths must stay trustworthy; UI never invents inventory claims.
5. Familiar mobile POS affordances (scan, cart, checkout, history) over novel patterns.

## Accessibility & Inclusion

Touch targets large enough for gloved or hurried use; high contrast for shop lighting; avoid relying on color alone for error vs success.

## Assumptions (inferred — confirm with `/impeccable init`)

- Primary platform remains Android (current ship target).
- Visual goal is category-standard professional POS craft (Square / Toast / Shopify POS bar), light mode for fluorescent shop floors.
- Brand green + restrained gold accent is binding enough to carry without a rebrand.
