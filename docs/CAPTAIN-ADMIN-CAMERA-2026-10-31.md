# Captain approval, guided camera and responsiveness — 31 October 2026

## What changed

The admin form previously disabled its decision buttons until every requirement
was satisfied, without explaining the missing items beside those buttons. The
reported application had no review note, society selection or approval
acknowledgments. The corrections checkboxes are separate from approval.

The form now lists the missing requirements beside the actions and gives visible
feedback when Approve is pressed. A valid form still opens the existing explicit
confirmation. Saving is guarded against duplicate submission, has a 30-second
request timeout, and reports server failures beside the action. Server-enforced
reviewer access, fresh Google authentication, application version checks and human
identity/payout review remain required. No real Captain was approved as a test.

The live-browser check also reproduced stale admin modules after a normal reload:
the previous Hosting response cached those assets for one hour. Admin builds now
version their complete local module graph and CSS together, and `/admin/**`
responses require revalidation. Two additional build tests verify cache busting,
configuration changes, reproducible output and Hosting cache headers.

To approve at https://wheelio-apps.web.app/admin/: open the submitted application,
review its private Aadhaar photo, selfie and payout details, select the societies
you approve, tick the two review acknowledgments, and write a review note of
5–1000 characters. Choose Approve and then Confirm review only after making your
human review decision. Use Verify Google session if the server requests a fresh
login. The Captain must also meet coverage, work-hour, Online and other real
eligibility requirements before appearing in Customer availability.

Captain W06 now opens the front camera inside its existing oval when the screen
appears. The existing white shutter captures directly, instead of launching the
phone's separate camera app. Captain job-photo screens use the same approach
inside the existing vehicle guide. Existing layouts, assets, typography, colours,
shutter sizes and navigation destinations are preserved. Loading feedback stays
inside the existing controls. A captured selfie remains visible during upload;
the KYC step advances only after Firebase accepts it. An upload failure leaves the
step incomplete and restores the camera for retry.

Shared camera startup is coalesced and safely handles permission-dialog pauses,
background/resume, capture in flight, navigation and disposal. Late callbacks
cannot reopen a departed screen or commit a stale capture. Customer camera
recovery after Settings is fixed, and an initializing guided camera no longer
silently falls back to a separate system camera. The explicit gallery action
remains available. Payout saving and application submission show their real
pending state and reject duplicate taps. The simulated five-second upload timer
now runs only in the disconnected demo, never the live Captain flow. Aadhaar's
fixed 2.2-second presentation delay is also demo-only; live uploads continue as
soon as the actual quality check finishes.

## Verification

- All four Flutter analyses pass.
- 105 Flutter tests pass: Customer 57, Captain 14, shared UI 9, Firebase 25.
- 155 backend/emulator tests pass. These include document submission/review,
  authorized approval, approval-to-Online/availability, unapproved access blocking,
  bookings, assignment, progress/completion and financial/security cases.
- New focused tests cover direct front-camera capture, upload failure/retry,
  permission lifecycle races, cleanup, stale capture rejection, duplicate payout
  and submission actions, and admin form requirements. Fake camera hardware and
  disposable test accounts run only in isolated tests, never production.

Ten affected authored screen states pass a before/after render comparison against
957ee5b (the pre-refinement source): nine are pixel-exact. W32 differs in 538
antialiased pixels, with a maximum colour-channel change of 5/255 and no pixels
over the audit tolerance. This preserves the current UI; it is not a replacement
for the historical af036f0 design audit. Results are saved in
`output/android-native-2026-10-31/refinement-design-results.json`.

Device and publication evidence is recorded below after the corresponding
checks. Automated and Android results do not establish iPhone
camera, Apple signing, APNs, payment-app switching or physical acceptance. Live
content still depends on actual network/server responses; it is not replaced by
guessed data or an artificial successful state. No extra warm-instance billing
or new external service is introduced.

## Published admin browser check

The default Firebase Hosting release was published and checked in the owner's
open Chrome admin session. After a normal reload, the live submitted application
loaded with enabled decision actions and the requirements beside them. Pressing
Approve on the incomplete form visibly showed the required note, acknowledgments
and society selection, without opening final confirmation or recording a review.
The application remained Awaiting review with no review history. Private browser
evidence is kept only in ignored local cache, not in Git. The separate
`washkrew.com` Hosting site and backend reviewer permissions were unchanged.
