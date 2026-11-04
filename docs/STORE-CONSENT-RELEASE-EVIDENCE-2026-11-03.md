# Current release artifacts with optional Google AI consent

3 November 2026. These Customer 1.0.4 (7) and Captain 1.0.5 (8) production
bundles supersede the earlier 6/7 artifacts. Built from clean committed source
**8b41dcf5360b21ae2b8db77e1900cb88dbd8db42**. Both passed official bundletool, signature/certificate,
package/version/API 36, three complete ABIs, 16 KB native LOAD/package alignment,
non-debug/backup settings and embedded R8 mapping checks. No public Play release
was submitted or installed during these build checks.

| Artifact | Bytes | SHA-256 |
| --- | --- | --- |
| WashKrew-Customer-1.0.4-7.aab | 52686205 | `a0e6bcf3c285bea0adc3f73b518eb9ee70e6e27c22ba07694338f72225723274` |
| WashKrew-Captain-1.0.5-8.aab | 54252170 | `61e3b5e8bb260baf6ee5b6cd6fc8b4c1324960b4bf1efb91cf7b4ad062c05483` |

Artifacts and exact mapping/provenance files are in `build/store/android/`.
Forward `build/store/WashKrew-Android-Store-Consent-2026-11-03.zip` separately;
ignored generated binaries and private signing keys are not in the Git push.
The ZIP contains only these two production bundles, mapping/JSON files, a README
and the current guides/evidence. It contains no private keys, KYC or payment data.

Backend: updateWashProgress deployed first, then createBooking/createCheckout/
checkWashPhotos; all four ACTIVE, minInstances 0, anonymous HTTP 401. Downloaded
function source matches the tested modules. Existing API gateways configured
without changing organization policy or application authorization.

Tests: 204 backend emulator tests and 184 Flutter tests passed (Customer 77,
Captain 40, shared UI 11, shared Firebase 56); all four package analyses passed.
No real-photo Gemini request, real payment or real-person approval was used as
an automated test. Native iOS source checks pass; physical iPhone/Xcode archive
and store review are not established by these Windows checks.

See `AI-PHOTO-CONSENT-2026-11-03.md`, `STORE-RELEASE-2026-11-03.md` and
`AMAN-CLAUDE-STORE-PUBLISH-2026-11-03.md`. Policy publication, contact verification,
store screenshots/disclosures/rating and private reviewer access remain owner
submission gates; consent implementation does not auto-approve those inputs.
