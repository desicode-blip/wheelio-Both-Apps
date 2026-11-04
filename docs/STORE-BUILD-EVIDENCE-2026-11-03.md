# Initial store build preparation — observed evidence

Historical evidence for the first 6/7 bundles. The later owner-approved consent
update is Customer 1.0.4 (7) / Captain 1.0.5 (8); use
`AI-PHOTO-CONSENT-2026-11-03.md` and the latest release receipt for current builds.

3 November 2026. Final production Android bundles were rebuilt from clean source
commit **a71164a8e569ca7285e1be7369802def19ee960b**. These are distinct from the
previous arm64 internal bundles. No Customer/Captain screen/component/design
source was changed by this release preparation.

| Bundle | Version/code | Bytes | SHA-256 |
| --- | --- | --- | --- |
| WashKrew-Customer-1.0.4-6.aab | 1.0.4 / 6 | 52681713 | 8bb1ceafbe0d10dc418a4ab9b4bc94c193fcdcb2006bcc612e106554775a6815 |
| WashKrew-Captain-1.0.5-7.aab | 1.0.5 / 7 | 54243300 | bd06ae6e55854a5162e0edc51767f0576f13e223e6b779d273af11265cc75518 |

Generated files are under `build/store/android/` (ignored by Git), alongside
exact R8 mappings and per-bundle provenance/verification JSON. Both use the
existing WashKrew private upload certificate, Flutter 3.38.6, live native Firebase
and explicit no-demo/no-emulator defines. Native R8/resource shrinking is enabled.

## Passed on this Windows machine

- Both production Gradle/appbundle builds; clean committed source provenance.
- Official Google bundletool 1.18.3 validation and ZIP CRC for each bundle.
- JAR signatures and the expected existing upload certificate for both apps.
- Exact expected package/version, target API 36, non-debuggable application,
  disabled app backup, no background-location permission.
- Complete armeabi-v7a / arm64-v8a / x86_64 Flutter engine and AOT libraries.
- All 12 packaged 64-bit native libraries in each app have LOAD alignment at
  least 16 KB; bundle configuration requests PAGE_ALIGNMENT_16K.
- R8 mappings embedded in each AAB and retained alongside it.
- Standalone iOS source/tool tests, including rejecting demo/device/unsigned
  store archive arguments, old SDKs, wrong team/role and development entitlements.
- Dart tooling analysis: no issues. Python ELF-validator regressions: 2 passed.
- Store metadata/source checks; opaque 1024px source icons; privacy-manifest
  plist structure and PBX resource inclusion for both apps.
- Five generated draft policy previews have valid local navigation and the
  deletion email-request link. Attempting to stage unapproved policies is refused.

The final source rebuild reproduced the same Android SHA-256 values as the
initial working-tree production builds. Verification was then rerun against the
clean-source artifacts and updated provenance.

## Not performed / still required

- No production AAB uploaded to Play and no public release submitted by this task.
  No device reinstall or new paid booking was made during build preparation.
  The owner’s report of Aman's functional approval is recorded separately.
- No macOS/Xcode execution, signed IPA export, archive privacy report or new
  physical iPhone test was possible on this Windows machine. The new archive
  command is prepared and portable checks pass; actual Mac output remains required.
- Public policy/support/deletion pages are drafts outside Hosting. Live public
  config read returned no support/legal fields. Owner CLI authentication was
  expired; no config, merchant, backend or website mutation was made.
- The full submission check correctly reports unfinished policy/contact/retention,
  store privacy/rating, safe reviewer access, screenshots and App Store record IDs.
  The AI-consent UI decision was requested; no unapproved screen/dialog was added.
- Native alignment/package checks do not establish runtime acceptance on every
  architecture or a physical 16 KB device, nor Apple/Google review approval.

Use [the current publishing guide](STORE-RELEASE-2026-11-03.md) and
[Aman's Claude prompt](AMAN-CLAUDE-STORE-PUBLISH-2026-11-03.md) to complete the
remaining Mac/store/owner steps. Do not hide or relabel an unfinished gate.
