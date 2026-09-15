# Design system

<!-- impeccable:design-schema 1 -->

## World

Dense Swiss / Square-style mobile POS polished around the official **Pyx POS Food Products** seal. Task-first checkout under shop-floor light.

## Brand mark

- Launcher / adaptive icons generated from `assets/pyx_pos_logo.png`
- In-app mark: `assets/pyx_pos_mark.png` (login hero)
- Receipt mark remains `assets/pyxfoodpr.png`

## Palette

| Token | Hex | Role |
|---|---|---|
| Forest | `#205010` | Seal green — primary, nav, scan CTA |
| Forest deep | `#143508` | Strong brand surfaces |
| Charge | `#059669` | Pay / AR money actions |
| Gold | `#C8900A` | Secondary RTS accent |
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

- Login: centered seal + Sign in panel
- Checkout workbench header with staff + printer status
- Large scan hero; sticky Charge bar with 10%/20%
- 4-tab NavigationBar: Sell · AR · History · Settings
- App label: **Pyx POS**

## Motion

Subtle Material ripple only. No page-load choreography.

## Authority files

- `design-system/pyx-pos/MASTER.md`
- Tokens in `lib/src/theme/pos_theme.dart`
