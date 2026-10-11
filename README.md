# Wheelio

Pay-per-wash, photo-verified exterior wash for cars and bikes in Hyderabad gated societies. "Wheelio" is a working name.

## Build order

Decided 10 Oct 2026: both apps are native iOS apps in Swift (SwiftUI), built with Xcode. Android comes later.

1. Customer app – iOS (`ios/` → Customer target) ← runs in the simulator on sample data
2. Washer app – iOS (`ios/` → Washer target; Hindi, Telugu, English) ← runs in the simulator on sample data
3. Android versions of both – later

Open `ios/Wheelio.xcodeproj`, pick the Customer or Washer scheme, and press Run. In each app, the **Screens** tab on the left edge opens any designed screen; in the washer app, **Step through all screens** walks W01–W50 with ‹ › buttons.

The Flutter code in `apps/` and `packages/` is the earlier approach and is no longer used.

## What's in this folder

| Path | Contents |
|---|---|
| `apps/customer/` | Flutter customer app: every customer screen C01–C55 and the Android differences, running on sample data |
| `packages/wheelio_ui/` | Wheelio design system for Flutter: colours, type, spacing and all shared widgets |
| `backend/supabase/` | Database schema with security rules, sample data, and server functions (payment webhook, AI photo check) |
| `backend/API-CONTRACT.md` | What each app action calls on the server |
| `backend/whatsapp-templates.md` | Entry-pass bot messages for Meta approval |
| `designs/` | Export of the Claude Design file (124 screens) plus the design read-me |
| `docs/STATUS.md` | What is done, what is waiting, and why |
| `docs/CONNECT-LATER.md` | Step by step: what you set up, and what Claude does after each step |
| `docs/BUILD-BRIEF.md` | Build plan, accounts and open decisions |
| `docs/screen-index.csv` | Every screen with its flow and navigation links |
| `tool/bootstrap_customer.sh` | One command to set up the app once Flutter is installed |
| `CLAUDE.md` | Project notes for future Claude Code sessions |

`Wheelio-designs/` is an extra copy of the design export made when this folder was first set up. It's the same as `designs/` and is safe to keep or delete.

## Online sources

- Design (live): https://claude.ai/artifact/QrsfqjaXnQ9fpY7spb1XAN
- Google Drive "Wheelio" folder: https://drive.google.com/drive/folders/1iIwNXlTps-X5rACETmyfAqnT9boJ3kpU
