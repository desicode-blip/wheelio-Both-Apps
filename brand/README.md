# WashKrew brand assets

Supplied by Aman on 25 October 2026. Wheelio is retired; the product and company are **WashKrew** (company written WASHKREW). Website: washkrew.com. Tagline: "Vehicle cleaning, on demand".

## Which file to use

- **Light theme (default, almost everything):** `washkrew-logo-light.svg` — the hero logo. Charcoal "Wash" and door, blue "Krew" and cloth.
- **Dark theme (rare):** `washkrew-logo-dark.svg` — same lockup, white "Wash" and door.
- Use **SVG** wherever the logo must stay sharp at any size (print, vehicles, uniforms, large screens). Use the **PNG** versions otherwise.

| File | What it is |
|---|---|
| `washkrew-logo-light.svg/.png` | Hero horizontal lockup with tagline, light backgrounds (original artwork, generous margins) |
| `washkrew-logo-dark.svg/.png` | Same, dark backgrounds |
| `washkrew-stacked-light.svg/.png` | Square stacked lockup (mark above name), light |
| `washkrew-stacked-dark.svg/.png` | Square stacked lockup, dark |
| `washkrew-mark-circle.png` | Door mark on a white circle (avatars, social) |
| `washkrew-lockup-light.svg`, `-dark.svg` | Hero lockup cropped tight (derived, for apps) |
| `washkrew-wordmark-light.svg`, `-dark.svg` | Mark + "WashKrew" without tagline (derived, for small headers) |
| `washkrew-mark.svg`, `washkrew-mark-white.svg` | Door mark only, transparent (derived, for icons) |
| `mockups/` | Captain polo (back and chest), kit bag and bottle, van — the crew look |

Derived files reuse the original paths; only the crop changed or the tagline was left out. Do not recolour, redraw or stretch the logo.

## Colours in the logo

Charcoal `#22282D`; blue gradient `#4E7AE9` (top) to `#0049FF` (bottom). These differ slightly from the app tokens (navy `#172231`, primary `#3160FF`); the logo keeps its own colours.

## Where the apps use it

- Flutter: `WLogo` in `apps/flutter/packages/wheelio_ui/lib/src/brand.dart`, PNGs in `lib/brand/` (1x/2x/3x, rendered from these SVGs).
- App icons: Customer = door mark on white; Captain = white door mark on charcoal, so the two apps are easy to tell apart on one phone.
- iPhone launch screen and web splash: hero light lockup on white.
