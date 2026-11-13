import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart' show DesignPhoto;

import '../data/models.dart';
import '../data/store.dart';

// v2 CU-LIVE (5 Nov 2026): the customer uploads their society gate pass
// (MyGate / NoBrokerHood screenshot or a photo of a paper pass) from the
// booking screens. The assigned Captain sees it on "Go to vehicle" (W26/W27).
// Replaces the WhatsApp gate-pass card, which was never connected.

/// Asks camera or gallery, then hands the picked image to the store.
Future<void> pickGatePass(BuildContext context, Order o) async {
  final store = context.store;
  Future<void> pick(bool camera) async {
    Uint8List? bytes;
    try {
      bytes = await Device.pickImage(camera: camera);
    } catch (e) {
      store.set(() => store.toast = e is MediaAccessException ? e.message : '$e');
      return;
    }
    if (bytes == null) return;
    await store.uploadGatePass(o, bytes);
  }

  await showWAlert(
    context,
    title: 'Add your gate pass',
    message: 'A screenshot of your MyGate or society pass, or a photo of a paper pass.',
    actions: [
      AlertAction('Take photo', onTap: () => pick(true)),
      AlertAction('Choose from gallery', onTap: () => pick(false)),
      const AlertAction('Cancel', cancel: true),
    ],
  );
}

/// Gate pass card: upload, preview and change.
class GatePassCard extends StatelessWidget {
  const GatePassCard({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final o = order;
    final bytes = o.gatePassBytes;
    final path = o.gatePassPath;
    final has = bytes != null || path != null || (o.entryPassReceived && !store.isLive);
    final shared = o.entryPassReceived;
    final name = o.captain?.name ?? 'Your Captain';
    return WCard(
      padding: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WIconBox(WIcon.door, size: 44, tone: has ? Tone.ok : Tone.wait),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WText('Gate pass', WType.title),
                    WText(
                      !has
                          ? 'Needed if your society checks visitors.'
                          : shared
                          ? '$name can see it and show it at the gate.'
                          : 'Saved on this phone. Sharing with your Captain is being connected.',
                      WType.caption,
                    ),
                  ],
                ),
              ),
              if (has) WLink('Change', onTap: () => pickGatePass(context, o)),
            ],
          ),
          const SizedBox(height: 14),
          if (has)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: bytes != null
                  ? Image.memory(bytes, height: 150, width: double.infinity, fit: BoxFit.cover)
                  : DesignPhoto(path: path, height: 150, icon: WIcon.door, radius: 12),
            )
          else ...[
            const WText('Upload your MyGate or society entry pass, so your Captain can get in.', WType.body),
            const SizedBox(height: 14),
            // 13 Nov (Aman): sharing with the Captain isn't connected on the live server yet.
            ComingSoonGate(
              available: store.gatePassLive,
              feature: 'Gate pass sharing',
              showTag: false,
              child: WButton(store.gatePassLive ? 'Upload gate pass' : 'Upload gate pass · coming soon', icon: WIcon.camera, kind: ButtonKind.outline, onTap: () => pickGatePass(context, o)),
            ),
          ],
        ],
      ),
    );
  }
}
