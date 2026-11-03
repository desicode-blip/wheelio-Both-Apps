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
              child: const WText('AI wash photo check', WType.title),
            ),
            const SizedBox(height: 8),
            const WText(
              'Turn on to allow this booking’s 4 after-wash vehicle photos to be sent to Google Vertex AI (Gemini) for dirt/photo-quality suggestions. Plates and surroundings may be visible. Aadhaar, selfies and bank details are excluded.',
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
