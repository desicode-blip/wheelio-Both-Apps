# WashKrew Customer (Flutter)

Current Android/iOS Customer app, source version **1.0.3 (4)**, using the shared
Flutter UI/Firebase packages. Keep the authored **af036f0** design and approved
exceptions in the root AGENTS.md. Android and iOS platform projects are included;
browser support is a QA preview of this same code, not another implementation.

On Aman's Mac follow [the current iPhone handoff](../../../docs/AMAN-IOS-HANDOFF-2026-11-02.md)
and [Claude retest prompt](../../../docs/AMAN-CLAUDE-IPHONE-RETEST-2026-11-03.md).
From the repository root:

```sh
bash apps/flutter/tool/run-ios.sh --prepare
bash apps/flutter/tool/run-ios.sh
```

The helper builds both Release apps. Use each ios/Runner.xcworkspace with the
existing paid Apple team and bundle ID. See [Flutter commands](../../../docs/FLUTTER.md)
and [Play internal testing](../../../docs/PLAY-INTERNAL-2026-11-01.md) for Android.
