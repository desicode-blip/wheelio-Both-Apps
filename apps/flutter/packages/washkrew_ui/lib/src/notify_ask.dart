import 'package:flutter/material.dart';

import 'components.dart';
import 'device.dart';
import 'icons.dart';

/// v2 SH-NOTIFY: the one-time "turn on notifications" screen shown after
/// install, in both apps. When notifications were already refused in iOS
/// Settings, the primary button opens Settings instead and the message says
/// exactly what to switch on there.
class WNotifyAsk extends StatefulWidget {
  const WNotifyAsk({
    super.key,
    required this.status,
    required this.title,
    required this.message,
    required this.deniedHelp,
    required this.turnOnLabel,
    required this.openSettingsLabel,
    required this.notNowLabel,
    required this.onTurnOn,
    required this.onNotNow,
    this.captain = false,
  });

  /// Current system permission (allowed / denied / not asked yet).
  final Future<Permission> Function() status;
  final String title, message, deniedHelp, turnOnLabel, openSettingsLabel, notNowLabel;

  /// Called with true when the system permission was already denied
  /// (the app should open Settings), false when it can show the iOS prompt.
  final Future<void> Function(bool denied) onTurnOn;
  final VoidCallback onNotNow;
  final bool captain;

  @override
  State<WNotifyAsk> createState() => _WNotifyAskState();
}

class _WNotifyAskState extends State<WNotifyAsk> {
  Permission? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.status().then((p) {
      if (mounted) setState(() => _status = p);
    }).catchError((Object _) {
      if (mounted) setState(() => _status = Permission.unknown);
    });
  }

  @override
  Widget build(BuildContext context) {
    final denied = _status == Permission.denied;
    return WScreen(
      scrolls: false,
      children: [
        Expanded(
          child: WFullState(
            icon: WIcon.bell,
            title: widget.title,
            message: denied ? '${widget.message}\n\n${widget.deniedHelp}' : widget.message,
            primary: denied ? widget.openSettingsLabel : widget.turnOnLabel,
            secondary: widget.notNowLabel,
            captain: widget.captain,
            onPrimary: _busy || _status == null
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await widget.onTurnOn(denied);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            onSecondary: widget.onNotNow,
          ),
        ),
      ],
    );
  }
}
