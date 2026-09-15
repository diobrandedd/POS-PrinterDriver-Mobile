# Design system

<!-- impeccable:design-schema 1 -->

## World

Dense Swiss / Square-style mobile POS. Task-first checkout: scan → cart → charge. Fluorescent shop-floor light mode.

Source: ui-ux-pro-max (`mobile POS retail`, Minimalism & Swiss, density 8) + Square Retail cart/charge patterns. Pyx brand colors override the skill’s navy primary.

## Palette

| Token | Hex | Role |
|---|---|---|
| Forest | `#145C45` | Brand primary, nav, scan CTA |
| Charge | `#059669` | Pay / AR money actions (Square-like) |
| Gold | `#C8900A` | Secondary brand accent |
| Ink | `#0F172A` | Body text |
| Muted | `#475569` | Secondary labels |
| Line | `#E2E8F0` | Borders |
| Surface | `#F8FAFC` | App background |
| Danger | `#DC2626` | Errors / refund |

## Typography

- Headings: **Rubik**
- Body: **Nunito Sans**
- Tabular figures for ₱ amounts

## Layout patterns

- Checkout workbench header with staff + printer status
- Large scan hero (56dp)
- Receipt-like cart rows, 40dp qty steppers (≥48dp effective with padding)
- Sticky **Charge** bar with 10% / 20% discount chips
- Scan sheet as bottom sheet (keyboard-safe)
- 4-tab NavigationBar: Sell · AR · History · Settings

## Motion

Subtle Material ripple only (motion dial 3). No page-load choreography.

## Authority files

- `design-system/pyx-pos/MASTER.md` (ui-ux-pro-max persist)
- Brand overrides live here and in `lib/src/theme/pos_theme.dart`
