import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'live_backend.dart';

/// The payment environment comes from the same server configuration as pricing.
class PaymentEnvironmentLabel extends StatelessWidget {
  const PaymentEnvironmentLabel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final backend = WashKrewRuntime.backend;
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
  late Future<Uint8List?> bytes = WashKrewRuntime.backend!.photo(widget.path);
  @override
  void didUpdateWidget(covariant PrivatePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path)
      bytes = WashKrewRuntime.backend!.photo(widget.path);
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
  late var locations = WashKrewRuntime.backend!.tracking(widget.orderId);
  Timer? refresh;
  @override
  void initState() { super.initState(); refresh=Timer.periodic(const Duration(seconds:30),(_) {if(mounted)setState((){});}); }
  @override
  void didUpdateWidget(covariant CaptainTracking oldWidget) {super.didUpdateWidget(oldWidget);if(oldWidget.orderId!=widget.orderId) locations=WashKrewRuntime.backend!.tracking(widget.orderId);}
  @override
  void dispose() {refresh?.cancel();super.dispose();}
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
              WButton('View on Google Maps',kind:ButtonKind.outline,onTap:() {Device.openLocation(data['latitude'],data['longitude']);}),
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
