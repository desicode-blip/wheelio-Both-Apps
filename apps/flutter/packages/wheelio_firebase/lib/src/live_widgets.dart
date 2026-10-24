import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';
import 'live_backend.dart';
import 'backend.dart';

/// The payment environment comes from the same server configuration as pricing.
class PaymentEnvironmentLabel extends StatelessWidget {
  const PaymentEnvironmentLabel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final backend = WheelioRuntime.backend;
    if (backend == null) return child;
    return StreamBuilder(
      stream: backend.catalog,
      builder: (context, snapshot) => Column(
        children: [
          if (snapshot.data?.data()?['paymentMode'] != 'live')
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFFFE8B0),
                padding: const EdgeInsets.all(7),
                child: const Text(
                  'TEST PAYMENTS · No real money is charged',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C4200),
                  ),
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Authenticated downloads keep wash and identity photos out of public URLs.
class PrivatePhoto extends StatefulWidget {
  const PrivatePhoto(this.path, {super.key, this.height = 180});
  final String path;
  final double height;
  @override
  State<PrivatePhoto> createState() => _PrivatePhotoState();
}

class _PrivatePhotoState extends State<PrivatePhoto> {
  late Future<Uint8List?> bytes = WheelioRuntime.backend!.photo(widget.path);
  @override
  void didUpdateWidget(covariant PrivatePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path)
      bytes = WheelioRuntime.backend!.photo(widget.path);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: FutureBuilder(
      future: bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(
            child: WText('Photo unavailable. Reopen to retry.', WType.caption),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(snapshot.data!, fit: BoxFit.contain),
        );
      },
    ),
  );
}

class CaptainTracking extends StatefulWidget {
  const CaptainTracking(this.orderId, {super.key});
  final String orderId;
  @override
  State<CaptainTracking> createState() => _CaptainTrackingState();
}

class _CaptainTrackingState extends State<CaptainTracking> {
  late var locations = WheelioRuntime.backend!.tracking(widget.orderId);
  Timer? refresh;
  @override
  void initState() {
    super.initState();
    refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant CaptainTracking oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId)
      locations = WheelioRuntime.backend!.tracking(widget.orderId);
  }

  @override
  void dispose() {
    refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: locations,
    builder: (context, snapshot) {
      final data = snapshot.data?.data();
      final time = data?['updatedAt']?.toDate() as DateTime?;
      final stale =
          time == null || DateTime.now().difference(time).inMinutes >= 2;
      return WCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WText(
              stale
                  ? 'Captain location unavailable'
                  : 'Captain’s shared location',
              WType.title,
            ),
            if (data != null) ...[
              WText(
                '${(data['latitude'] as num).toStringAsFixed(5)}, ${(data['longitude'] as num).toStringAsFixed(5)}',
                WType.body,
              ),
              WText(
                'Updated ${time?.toLocal().toString().substring(0, 19) ?? '—'}${stale ? ' · Last known location' : ''}',
                WType.caption,
              ),
              const Gap(12),
              WButton(
                'View on Google Maps',
                kind: ButtonKind.outline,
                onTap: () {
                  Device.openLocation(data['latitude'], data['longitude']);
                },
              ),
            ] else
              const WText(
                'Your captain can share location during this wash. Booking stages update automatically.',
                WType.caption,
              ),
          ],
        ),
      );
    },
  );
}

/// Download through authenticated Storage access; no public media URLs.
class PrivateMedia extends StatefulWidget {
  const PrivateMedia(this.data, {super.key});
  final Map<String, dynamic> data;
  @override
  State<PrivateMedia> createState() => _PrivateMediaState();
}

class _PrivateMediaState extends State<PrivateMedia> {
  late final loading = WheelioRuntime.backend!.media(widget.data['path']);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: loading,
    builder: (context, s) {
      if (s.hasError)
        return const Text(
          'Recording unavailable. Reopen the booking to retry.',
        );
      if (!s.hasData) return const CircularProgressIndicator();
      return MediaPreview(
        MediaClip(
          bytes: s.data!,
          contentType: widget.data['contentType'],
          seconds: (widget.data['seconds'] as num).toInt(),
        ),
      );
    },
  );
}

class SupportRequestForm extends StatefulWidget {
  const SupportRequestForm({super.key});
  @override
  State<SupportRequestForm> createState() => _SupportRequestFormState();
}

class _SupportRequestFormState extends State<SupportRequestForm> {
  final requestId = DateTime.now().microsecondsSinceEpoch.toString();
  String kind = 'other', note = '', message = '';
  bool busy = false, saved = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Contact Wheelio operations',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const Text(
        'Your message is saved for review. No response time is promised. Account deletion and phone changes require verification by operations.',
      ),
      if (!saved) ...[
        DropdownButtonFormField<String>(
          initialValue: kind,
          items: [
            for (final item in [
              ('booking', 'Booking'),
              ('payment', 'Payment or refund'),
              ('phoneChange', 'Change phone'),
              ('accountDeletion', 'Delete account'),
              ('other', 'Other'),
            ])
              DropdownMenuItem(value: item.$1, child: Text(item.$2)),
          ],
          onChanged: busy ? null : (v) => setState(() => kind = v!),
        ),
        TextField(
          maxLength: 1000,
          maxLines: 3,
          onChanged: (v) => setState(() => note = v),
          decoration: const InputDecoration(labelText: 'Your message'),
        ),
        FilledButton(
          onPressed: busy || note.trim().length < 5
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await WheelioRuntime.backend!.call('createSupportRequest', {
                      'requestId': requestId,
                      'kind': kind,
                      'note': note.trim(),
                    });
                    if (mounted)
                      setState(() {
                        saved = true;
                        message =
                            'Request saved. Wheelio operations will review it.';
                      });
                  } catch (e) {
                    if (mounted) setState(() => message = backendError(e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'Saving…' : 'Send request'),
        ),
      ],
      if (message.isNotEmpty) Text(message),
    ],
  );
}

class FirebaseInbox extends StatefulWidget {
  const FirebaseInbox({super.key, required this.captain, required this.onOpen});
  final bool captain;
  final void Function(String id) onOpen;
  @override
  State<FirebaseInbox> createState() => _FirebaseInboxState();
}

class _FirebaseInboxState extends State<FirebaseInbox> {
  final backend = WheelioRuntime.backend!;
  String message = '';
  bool busy = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Your updates',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      if (backend.supportsPush)
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await backend.enablePush(
                      widget.captain ? 'captain' : 'customer',
                    );
                    if (mounted)
                      setState(() => message = 'iPhone alerts enabled.');
                  } catch (e) {
                    if (mounted) setState(() => message = backendError(e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: const Text('Enable iPhone notifications'),
        ),
      if (backend.supportsPush)
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  try {
                    await backend.call('setPushPreference', {
                      'role': widget.captain ? 'captain' : 'customer',
                      'enabled': false,
                    });
                    if (mounted)
                      setState(
                        () => message =
                            'Push alerts disabled. Updates stay in your inbox.',
                      );
                  } catch (e) {
                    if (mounted) setState(() => message = backendError(e));
                  }
                },
          child: const Text('Disable push alerts'),
        ),
      if (message.isNotEmpty) Text(message),
      if (backend.uid != null)
        StreamBuilder(
          stream: backend.inbox(backend.uid!),
          builder: (context, s) {
            if (s.hasError)
              return const Text(
                'Updates could not load. Reopen this screen to retry.',
              );
            if (!s.hasData) return const CircularProgressIndicator();
            final docs =
                s.data!.docs
                    .where(
                      (d) =>
                          d.data()['role'] ==
                          (widget.captain ? 'captain' : 'customer'),
                    )
                    .toList()
                  ..sort(
                    (a, b) =>
                        (b.data()['createdAt']?.toDate() as DateTime? ??
                                DateTime(1970))
                            .compareTo(
                              a.data()['createdAt']?.toDate() as DateTime? ??
                                  DateTime(1970),
                            ),
                  );
            return Column(
              children: [
                if (docs.isEmpty)
                  const Text('Booking updates appear here automatically.'),
                for (final doc in docs)
                  ListTile(
                    minTileHeight: 64,
                    leading: Icon(
                      doc.data()['read'] == true
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                    ),
                    title: Text(doc.data()['title']),
                    subtitle: Text(doc.data()['body']),
                    onTap: () async {
                      try {
                        await backend.call('readNotification', {
                          'notificationId': doc.id,
                        });
                        if (!mounted) return;
                        widget.onOpen(doc.data()['orderId']);
                      } catch (e) {
                        if (mounted) setState(() => message = backendError(e));
                      }
                    },
                  ),
              ],
            );
          },
        ),
    ],
  );
}
