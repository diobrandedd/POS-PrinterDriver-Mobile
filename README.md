# POS Thermal (Mobile)

Android POS terminal for Pyx Tracker / RTS with Bluetooth ESC/POS printing (no watermark).

## Features
- POS PIN login against RTS (`Bearer` token)
- Sell (barcode lookup → cash checkout → auto-print)
- AR credit checkout
- Sales history, reprint, full-sale refund (updates RTS website data)
- Printer: Bluetooth / USB / Wi‑Fi 9100

## Default API
`https://pyxtracker.pyxfood.com/rts/api/v1`

Changeable in the login screen or Settings.

## RTS server requirements
This app needs the mobile POS API changes in the RTS repo:
- Bearer tokens on `auth.php?action=pos_login`
- `pos.php?action=sales_history|receipt_get|sale_refund`

See `sql/migration_phase80_pos_mobile_tokens.sql` in the RTS project.

## Run
```bash
flutter pub get
flutter run
```
