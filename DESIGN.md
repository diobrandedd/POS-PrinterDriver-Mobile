# Design system

<!-- impeccable:design-schema 1 -->

## World

Category-standard mobile POS craft (Square / Toast / Shopify POS bar), Operate mode, light surfaces for fluorescent shop floors. Task speed over spectacle.

## Palette

| Token | Hex | Role |
|---|---|---|
| Forest | `#145C45` | Primary actions, nav selection |
| Forest deep | `#0B3D2E` | Strong text on soft fills, snackbars |
| Forest soft | `#E6F0EB` | Chips, nav indicator, soft surfaces |
| Gold | `#C8900A` | Money CTAs (pay / AR checkout) |
| Ink | `#14201C` | Body text |
| Muted | `#5A6B63` | Secondary labels |
| Line | `#D5DDD8` | Borders |
| Surface | `#F3F5F4` | App background |
| Danger | `#B42318` | Errors / destructive refund |

## Typography

Platform sans via Material 3. Tight hierarchy: 28/800 page titles, 20/700 section titles, 14–16 body, tabular figures for money (`₱`).

## Components

- **PosScrollPage / PosPage** — consistent page chrome (title, subtitle, staff chip).
- **PosPanel** — white 16px radius panel, 1px line, soft offset shadow.
- **StaffChip** — signed-in identity always visible on task screens.
- **CheckoutBar** — sticky full / 10% / 20% pay actions.
- **PosErrorBanner / PosEmptyHint / StatusPill** — honest empty and error states.
- **Printer settings** live under Settings (no separate Printer tab).

## Motion

Material ink only; 150–250ms state feedback. No orchestrated page entrances.

## Platform

Android Material 3. NavigationBar with four destinations: Sell, AR, History, Settings.
