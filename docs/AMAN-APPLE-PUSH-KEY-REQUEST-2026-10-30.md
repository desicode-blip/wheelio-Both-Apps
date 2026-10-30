# What Ajay needs from Aman for iPhone notifications

The Apple signing work is already in Aman's staging code. Firebase project
`wheelio-apps` has both registered iOS apps. The remaining credential for push
activation is an **Apple Push Notification service (APNs) authentication key**
from the paid Apple team **28JNT7H8KA**. This is separate from Razorpay and the
Firebase Google login. Do not send an Apple password or SMS code.

## Message to forward

"Aman, please check the paid Apple Developer account, team 28JNT7H8KA, for an
existing Apple Push Notifications authentication key. We need the downloaded
AuthKey .p8 file, its Key ID, and which environment(s) it supports, so we can
connect Firebase notifications for both WashKrew apps. The app bundle IDs are
com.amanmaheshwari.wheelio.customer and com.amanmaheshwari.wheelio.captain.
Please share the file securely with Ajay, outside Git and public chat. Do not
revoke or regenerate a key used by another app. If no suitable key exists, the
Apple Account Holder/Admin needs to create and download one."

## If no suitable key exists

1. The Apple Account Holder/Admin opens
   [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/authkeys/list)
   and verifies the selected paid team is **28JNT7H8KA**.
2. Open Keys, add an appropriately named key, enable Apple Push Notification
   service and Configure it. Check the allowed environment and topic scope.
   When choosing topic-specific scope, include the two bundle IDs above.
3. Provide sandbox/development access for the installed development-signed
   iPhone apps. TestFlight/App Store builds also need production access. If
   Apple offers separate environment keys, retain the corresponding files,
   Key IDs and environment labels; do not assume every key works in both.
4. The human reviews/confirms creation, downloads the `.p8` once and stores it
   securely. Record the Key ID and team alongside it. It is not an App Store
   Connect API key or a `.p12` certificate. Apple cannot re-download that private
   key after its one-time download; locate the saved original before changing
   any existing key.

These steps follow [Apple's key-creation instructions](https://developer.apple.com/help/account/keys/create-a-private-key/).
Apple requires the Account Holder or Admin role and lets the creator configure
environment/topic scope. No signing keys, provisioning profiles or app IDs need
to be replaced for this backend task.

## Firebase connection and actual acceptance

Once the correct file/Key ID is available, use
[wheelio-apps Cloud Messaging settings](https://console.firebase.google.com/project/wheelio-apps/settings/cloudmessaging).
For each existing iOS app, upload the appropriate APNs authentication key with
its Key ID and team **28JNT7H8KA**. Follow the environment-specific fields shown
by Firebase and preserve any unrelated working credentials. See
[Firebase's Apple messaging setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

Then rebuild/reopen both real apps on Aman's iPhone, allow notifications and
verify token registration, foreground/background/lock-screen delivery and taps
to the correct app/order. Configuration or a successful FCM request alone is
not proof of actual phone delivery. Use only genuinely authorized account
events; do not approve a fake production Captain or send unsolicited test pushes.

The seller/company-name decision and any conversion from an Individual Apple
membership remain business/account work for Aman before App Store submission;
they are separate from this backend credential and device testing.
