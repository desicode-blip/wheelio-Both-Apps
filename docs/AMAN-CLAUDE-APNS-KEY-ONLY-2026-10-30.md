# Aman's Claude task: obtain the Apple notification key only

The owner clarified that Ajay's agent continues performance/backend work and
handles Firebase configuration. Aman's task here is only key preparation.
Copy the following prompt into Claude on Aman's Mac:

---

Help me obtain the Apple Push Notification service (APNs) authentication key
needed for both WashKrew apps.

- Apple Developer paid team: **28JNT7H8KA**.
- Customer bundle ID: `com.amanmaheshwari.wheelio.customer`.
- Captain bundle ID: `com.amanmaheshwari.wheelio.captain`.

First look for a suitable existing downloaded APNs `.p8` key on my Mac. If none
is available, guide me through creating/downloading one in the correct Apple
Developer team. I will complete Apple sign-in, verification and key-creation
confirmation myself. Do not revoke or regenerate keys used elsewhere.

Confirm that the key permissions cover both apps, and record its supported
environments/topic scope. Use
[Apple's key instructions](https://developer.apple.com/help/account/keys/create-a-private-key/).

We need to provide Ajay with:

1. The original `.p8` file.
2. Its Key ID.
3. The Apple Team ID.
4. Its environment/topic permissions.

Save the key securely **outside the repository**, and tell me which file to
transfer privately to Ajay. Never display its contents, bundle it in an app or
commit/push it to GitHub. Do not use chat or a public link for the private key.

Ajay will handle Firebase upload/configuration. Your task is only to obtain
this key and its details. Do not change app code or Firebase settings. If a
required Apple role or permission is missing, report that exact blocker.

---

If a handoff status note is committed to Git, it must contain only secret-free
status/metadata. The private `.p8` file itself is never the Git handoff.
