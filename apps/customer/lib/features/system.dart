import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import 'common.dart';

// ---------------------------------------------------------------------------
// C50-Offline. Shown over the flow that lost its connection; whatever the
// customer entered stays in the draft on the phone.

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) => WScreen(
        header: const SimpleHeader(),
        body: const WStateView(
          icon: Icons.wifi_off_rounded,
          tone: WTone.mute,
          title: 'You’re offline',
          body: 'Check your internet. Anything you entered is saved on this phone.',
        ),
        footer: WFooterBar(children: [
          WButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: () => goBack(context)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// C51-Error

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) => WScreen(
        header: const SimpleHeader(),
        body: const WStateView(
          icon: Icons.cloud_off_rounded,
          tone: WTone.error,
          title: 'Something went wrong on our side',
          body: 'It’s not you. Try again in a minute, or call us and we’ll sort it out.',
        ),
        footer: WFooterBar(vertical: true, children: [
          WButton(label: 'Try again', onPressed: () => goBack(context)),
          WButton.text(label: 'Call support', onPressed: () => openHelp(context)),
        ]),
      );
}
