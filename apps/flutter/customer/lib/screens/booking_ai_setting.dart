import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart' show backendError;
import '../data/models.dart';
import '../data/store.dart';

class BookingAiPhotoSetting extends StatefulWidget {
  const BookingAiPhotoSetting({super.key, required this.order});
  final Order order;
  @override
  State<BookingAiPhotoSetting> createState() => _BookingAiPhotoSettingState();
}

class _BookingAiPhotoSettingState extends State<BookingAiPhotoSetting> {
  bool saving = false;
  String? message;
  Future<void> _save(bool enabled) async {
    if (saving) return;
    final store = context.store;
    setState(() {
      saving = true;
      message = null;
    });
    try {
      final alreadySent = await store.setBookingPhotoAi(widget.order, enabled);
      if (mounted && !enabled && alreadySent) {
        setState(
          () => message =
              'Off. A check already sent to Google cannot be recalled.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => message = backendError(error));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    if (!context.store.isLive ||
        o.paymentStatus != 'captured' ||
        ![
          OrderStatus.searching,
          OrderStatus.onTheWay,
          OrderStatus.washing,
        ].contains(o.status)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: WCard(
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WToggleRow(
              on: o.aiPhotoCheckEnabled,
              onChanged: _save,
              enabled: !saving,
              child: Row(
                children: [
                  const Flexible(child: WText('AI wash photo check', WType.title)),
                  const SizedBox(width: 6),
                  // v2 CU-APPROVE: (i) explains the check in full.
                  Semantics(
                    button: true,
                    label: 'About the AI wash photo check',
                    child: Pressable(
                      onTap: () => showAiPhotoCheckInfo(context),
                      child: const Padding(padding: EdgeInsets.all(4), child: WIconView(WIcon.info, size: 18, color: WColor.secondary)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const WText(
              'Turn on to let Google AI (Vertex AI, Gemini) check your wash photos for missed spots before they reach you. Plates and surroundings may be visible. Aadhaar, selfies and bank details are never sent.',
              WType.caption,
            ),
            const SizedBox(height: 8),
            WText(
              saving
                  ? 'Saving…'
                  : o.aiPhotoCheckEnabled
                  ? 'On · The Captain can check with AI or send without checking.'
                  : 'Off · Photos go directly to you for review.',
              WType.caption,
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: WText(
                  message!,
                  WType.caption,
                  color: WColor.destructive,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// v2 CU-APPROVE (5 Nov 2026, Aman's wording): what the AI wash photo check does.
Future<void> showAiPhotoCheckInfo(BuildContext context) => showWAlert(
  context,
  title: 'AI wash photo check',
  message:
      'When your wash is done, we use Google AI (Vertex AI, Gemini) to compare the before and after photos of your vehicle. '
      'If it spots dirt or a part that wasn’t cleaned properly, we get it fixed before the photos come to you for review.\n\n'
      'Your photos are safe with us. Number plates and anything in the background are used only for this check and nowhere else. '
      'We delete wash photos after 90 days.\n\n'
      'This check is optional. When it’s off, the photos come straight to you for review.',
);
