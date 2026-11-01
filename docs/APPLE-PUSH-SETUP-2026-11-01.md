# Apple push key — 1 November 2026

Aman supplied the APNs authentication key privately. Its supplied metadata identifies paid team `28JNT7H8KA`, Key ID `Y5432Q73U8`, team-scoped topics, and sandbox/production use. Local cryptographic parsing verifies an EC P-256 private key; that does not independently verify Apple's authorization or delivery.

## Configuration status

Firebase project `wheelio-apps` → Project settings → Cloud Messaging → Apple app configuration now shows **saved development and production APNs authentication keys** for both maintained apps:

- `com.amanmaheshwari.wheelio.customer`
- `com.amanmaheshwari.wheelio.captain`

All four saved rows were verified visually on 1 November, with Key ID `Y5432Q73U8` and paid Team ID `28JNT7H8KA`. The browser extension's automated chooser initially rejected local file access; the standard Windows file picker completed the uploads. No extension permission or real-SMS verification protection was changed. Local screenshots of the saved metadata are kept in the ignored cache and were shown to the owner; no private key contents are included.

Never put the private key in this repository, a report, chat, browser logs or build artifacts. The file remains in the owner's Downloads outside Git; `.p8` files are ignored as additional protection. Keep a secure private backup because Apple does not offer another download of the original key.

## Native acceptance after upload

Both existing Flutter iOS projects retain the paid team, Push Notifications entitlement, Background fetch and Remote notifications modes. Firebase delegate swizzling is not disabled. No new UI, web CAPTCHA page or real-SMS verification bypass has been added.

On Aman's Mac, use each app's `ios/Runner.xcworkspace`, select the existing paid team, and refresh signing/provisioning for Push Notifications. Build and install both current apps on a physical iPhone. Verify native phone OTP with Background App Refresh enabled, foreground/background push delivery, and the existing booking/claim/tracking sequence using distinct legitimate role accounts and human approval. Enter SMS codes only on the device. Record actual results in [IOS-ACCEPTANCE-RESULTS-TEMPLATE.md](IOS-ACCEPTANCE-RESULTS-TEMPLATE.md).

Uploading a valid key is configuration evidence, not a physical-device result. Firebase may use secure reCAPTCHA fallback when silent verification is unavailable; never disable real app verification or promise zero challenges.

Official reference: [Firebase phone authentication on Apple platforms](https://firebase.google.com/docs/auth/ios/phone-auth).
