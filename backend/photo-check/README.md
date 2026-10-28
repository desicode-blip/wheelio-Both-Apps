# Private photo checks

**28 October update:** the owner requested completion after the separate merchant
live cutover. The actual private service passed runtime checks and is now enabled
for both test/live jobs via `privateConfig/photoChecks.paymentModes`. This explicit
array supersedes the legacy single `paymentMode` field; malformed lists fail
closed. `node backend/photo-check/activate.cjs live` verifies the deployed runtime
and matching configured service URI before atomically preserving existing modes
and adding live. It does not approve a Captain, training, KYC, a live transaction
or physical-device acceptance. See
[the completion report](../../docs/COMPLETION-2026-10-28.md) for remaining gates.

This service runs in the existing `wheelio-apps` project, with zero minimum instances. It is callable only through Google Cloud IAM by the Functions runtime account. App clients use Firebase-authenticated, assignment-checked callables; they never receive a server credential or direct service access. No additional merchant account is involved.

## Identity

YuNet detects one clearly visible face and SFace compares it **only** against that Captain's operator-approved private KYC selfie. Official OpenCV Zoo weights are pinned by commit and SHA-256 in `models.json`; MIT/Apache notices are included in `licenses/`. Embeddings and request images are not logged or stored by this container. The published OpenCV cosine baseline is used for an assistive candidate match; it is **not liveness detection or a claim of calibrated identity accuracy**. Real consenting phone captures must be accepted on hardware before live use.

The upload is one immutable, five-minute server-issued Storage attempt. Customers cannot read it. A candidate match allows the existing wash workflow to continue; uncertain comparisons need a recorded human review. No KYC approval, work restriction, employment decision or payout is made by the model. Clear matches/retakes attempt immediate deletion. Review captures and abandoned attempts are targeted for deletion after 24 hours by the five-minute maintenance task, including earlier retry paths. Cleanup failures are logged and retried; operators must investigate a persistent failure. Deleting the account also removes captures and private training subcollections.

## Vehicle photos

Only the four vehicle after-wash photos go to the configured Gemini model; Captain faces/KYC never go to Gemini. The private service produces bounded JPEG thumbnails. Gemini returns structured, advisory observations for the existing photo-check screen. Current model: `gemini-3.5-flash`, verified against [Firebase's model list](https://firebase.google.com/docs/ai-logic/models) on 26 October 2026 and through an actual provider request. Its location is `global`; final policies must describe the approved processing before launch. The runtime has a custom role containing only `aiplatform.endpoints.predict` and `serviceusage.services.use`, rather than broad AI administration access.

Uncertain/failed automatic review is labelled; a Captain can use the existing send-anyway control after acknowledging it. The owner still receives the actual private evidence and approves/reports the wash. A model response never releases money or resolves a dispute. Review results are bound to the server evidence fingerprint, deduplicated and rate limited; changed photos need a new review.

## Deploy and check

From the repository root with the Firebase owner CLI login:

```sh
node backend/photo-check/deploy.cjs
node backend/photo-check/configure-ai.cjs
node backend/photo-check/check.cjs
```

The deployer uses existing owner OAuth in memory, checksum-verifies downloaded models and builds a private Artifact Registry image. The build service account needs writer access **only** to the `washkrew-services` repository (already configured). IAM invoker access stays restricted; no `allUsers` grant is used. Configuration lives in server-only `privateConfig/photoChecks`. Redeploying preserves existing enable/mode settings; the initial mode is `test`. Live use needs explicit operational acceptance and an owner configuration change, independently of Razorpay's payment mode.

`check.cjs` creates and removes one short-lived Cloud Run job using the actual Functions service account. It checks private authentication, matching/different-person comparisons with public scientific fixtures, image quality/thumbnail output and actual Gemini structured image inference. It creates no Firebase user, captain, booking or payment. On Windows, the same models can be checked locally:

```sh
python -m venv .cache/photo-check-venv
.cache/photo-check-venv/Scripts/python -m pip install -r backend/photo-check/requirements.txt
.cache/photo-check-venv/Scripts/python backend/photo-check/download_models.py
.cache/photo-check-venv/Scripts/python -m unittest discover -s backend/photo-check -p '*_test.py'
```

Set `PHOTO_FIXTURE_DIR` only when supplying the optional public test fixtures described in the test. Downloads, models and local credentials must stay outside Git. Customer/Captain compilation on the Mac needs none of these server tools or secrets.
