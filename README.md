# Thermal Print

Personal Android ESC/POS thermal printer driver (RawBT-style) built with Flutter + Kotlin.

## Features

- Bluetooth Classic (SPP), USB Host, and Wi‑Fi/Ethernet (TCP port 9100)
- Pair/select printer and run a watermark-free test print
- Android system **Print Service** (Chrome, Docs, etc.)
- Share / Open images, PDF, and text into the app
- Custom URI schemes: `thermalprint:` and `rawprint:`
- 58mm (384 dots) and 80mm (576 dots), `GS v 0` or `ESC *`

Defaults are tuned for **KJ-5802H** and similar 58mm ESC/POS clones.

## Setup

1. Install Flutter and an Android device/emulator with Bluetooth if testing BT.
2. From this folder:

```bash
flutter pub get
flutter run
```

3. Pair your printer in Android Bluetooth settings (PIN often `0000` or `1234`).
4. Open **Printers** in the app → select the device → **Test print**.
5. Enable the print service: **Settings → Connected devices → Connection preferences → Printing → Thermal Print**.

## URI API

- `thermalprint:text,Hello%20World`
- `thermalprint:base64,<base64-esc-pos-or-text-bytes>`
- `thermalprint:data:text/plain;base64,<base64>`
- `thermalprint:data:image/png;base64,<base64>`
- Same with `rawprint:` scheme

## Notes

- No watermark is ever added to print output.
- For personal / sideload use. System Print Service and Share intents are Android-only.
