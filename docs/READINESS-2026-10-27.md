# Software completion and Mac handoff — 27 October 2026

**Later owner handoff decision:** [CLAUDE-MAC-CONTINUATION-2026-10-27.md](CLAUDE-MAC-CONTINUATION-2026-10-27.md) and the PDF in `output/pdf/` are the current continuation report. Aman will supply temporary training design placeholders, not working videos. They must not grant training completion. Aman is also handling the separate WashKrew merchant account Razorpay requested; prior shared live credentials are not an approved launch path. Integration/migration and new-merchant acceptance are still pending, with payments kept in test mode.

The active apps are Flutter Customer and Captain, using the staging design. This pass extends the functionality release in [FUNCTIONALITY-2026-10-26.md](FUNCTIONALITY-2026-10-26.md). Screen composition, assets, typography and design tokens were preserved; existing map, video, photo and microphone regions now operate real services. No generic replacement screen or removed payment banner was added. Android remains deferred.

## Added in this pass

- Real Google Maps in C08, including native runtime key setup, restricted separate web/iOS keys and a server-only Routes key. Captain foreground GPS can provide a real traffic-aware ETA, refreshed at most every 90 seconds; stale/outage estimates do not become invented arrival times. No background location promise was added.
- Verified Google's My Home Avatar place/name/pincode and saved its location/viewport. A viewport gives the Customer a suggestion to confirm, not permission to expand service. Avali's returned address/pincode differs from the catalog; Avishkaar has no exact match. Their coordinates and boundaries remain unconfigured pending actual coverage review. No radius was guessed.
- Real streaming training playback in W09, persisted bounded watch progress, versioned completion and authoritative grading of the existing five-question bank. Skipping/replaying a heartbeat cannot instantly complete training. Current required training/quiz can be enforced at application and operator approval. Live video completion never uses the demo timer. The existing quiz microphone now selects an unambiguous spoken answer using device speech recognition; final grading remains on the server.
- Genuine capture checks for darkness, unreadable/tiny/obscured photos, Aadhaar retry handling, and the correct before/after side on a retake. Camera shutter actions cannot overlap while the capture is being saved.
- Private one-to-one Captain photo checks, uncertain-result human review and cleanup, plus real advisory Gemini vehicle-photo review in W36. These are test-mode features and do not approve KYC, decide disputes or transfer money. See [the service notes](../backend/photo-check/README.md) for model/privacy/retention limits and reproducible deployed checks.
- Owner-only operator controls for agreed introduction-call times, work status, actual daily limits and review requests. Blocked/refresher Captains cannot take new jobs or contribute available capacity. Missing limits and unapproved payout/late-fee promises are not replaced with sample operational values.
- Runtime support and combined terms/privacy links plus an approved-content publisher. The owner confirmed **Aman will supply the actual content**. No contact number, legal entity, policy or training clip was invented or published.

## Approved content handoff

Complete a private copy of [APPROVED-CONTENT.example.json](APPROVED-CONTENT.example.json) with Aman's approved values. The three video entries must be direct HTTPS media URLs and have their real durations in seconds, matching car wash, bike wash and dos/don'ts in the existing screens. Review the authored quiz against those clips before publishing. `legal.termsPrivacyUrl` is the approved combined terms/privacy page. The privacy content must cover the actual microphone, location, image/identity and processor behavior. This document does not supply legal approval.

```sh
node backend/firebase/operator.cjs publish-content .cache/approved-content.json
node backend/firebase/operator.cjs publish-content .cache/approved-content.json --confirm
```

Blank examples are rejected. The preview and final publish do not change prices, payment mode, coverage or merchant credentials. Other operator commands use a reviewed private JSON input and the same preview/`--confirm` pattern: `schedule-intro`, `set-captain-policy`, `review-identity`, `resolve-dispute`, `record-payout`. Transfers and KYC/dispute/work decisions remain human operations.

## Verification and remaining boundaries

Release checks and exact final counts are recorded in [WEB-ACCEPTANCE.md](WEB-ACCEPTANCE.md). Deployed photo-service checks used the actual runtime identity and real inference endpoints, with public/synthetic fixtures and no production QA account or booking. This is distinct from a fresh end-to-end device booking/payment acceptance.

Fresh browser checks resumed through the connected in-app browser against isolated local Firebase emulators. Both Customer and Captain signed in and restored their sessions; Captain displayed the completed order and its approved earning. The actual Google street map loaded inside C08's existing region, dragging moved its center, and confirming parking saved that exact latitude/longitude in the Customer's private place. The latest map script uses the asynchronous callback loader. Screenshots are local QA evidence, not physical iPhone acceptance. The earlier native Chrome automation attempt stopped at its URL safety check and was not used for these checks.

The final UI pass also corrected live repeat-booking/optional-photo text and Captain's earnings caption: unconnected messaging and an unapproved midnight payout are not promised. These are text changes within the existing components; sample copy remains in the explicit demo app.

Use [MAC-HANDOFF.md](MAC-HANDOFF.md) for compilation, Apple signing/APNs and physical Release acceptance. Camera/microphone/speech allow/deny/re-enable, real SMS/reCAPTCHA, Maps/GPS, Razorpay app switching and pushes must be checked on real iPhones. Windows cannot prove an Xcode compile or signed install. Also test one real consenting Captain's KYC reference against fresh selfies; the model fixture checks do not establish liveness or field accuracy.

Separate non-device launch gates remain: Aman's content, reviewed live commercial/service coverage, Razorpay approval/live acceptance and real approved live Captains. DigiLocker, WhatsApp Business, voice-call OTP and masked calling need provider accounts/capabilities that are not available; the owner previously deferred those external integrations. Server payments remain **test**. Do not call the product live-ready solely because its source can be transferred to the Mac.
