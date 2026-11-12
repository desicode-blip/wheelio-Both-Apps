import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart' show backendError;

import '../data/store.dart';

// v2 CU-REVIEW (12 Nov 2026, Aman): refund coupons are shown up front on Check and pay —
// no typing a code. 1–2 coupons: each as a card with Apply. 3 or more: one
// "Discount coupons" button that opens them in a sheet. Applying turns the whole card
// green with a tick in the top-right corner, with Remove to undo.
// Coupons are Ajay's refund coupons (collection `coupons`, applied through the
// `previewRefundCoupon` callable in AppStore.applyCoupon). Only one applies per booking.

class RefundCoupon {
  const RefundCoupon({required this.code, required this.availablePaise, this.expires, this.sample = false});
  final String code;
  final int availablePaise;
  final DateTime? expires;

  /// Review-tools sample (no server): only the look is shown, payment is unchanged.
  final bool sample;
}

/// The customer's usable coupons, newest first: active, unexpired and with value left.
/// With review tools on and no real coupons, three samples show the look only.
Stream<List<RefundCoupon>> usableCoupons(AppStore store) => store.refundCouponDocs().map((docs) {
  final now = DateTime.now();
  final list = <RefundCoupon>[];
  for (final c in docs) {
    final raw = c['expiresAt'];
    final expires = raw is DateTime ? raw : (raw as dynamic)?.toDate() as DateTime?;
    final available = (c['availablePaise'] as num? ?? 0).toInt();
    if (c['status'] == 'active' && expires != null && expires.isAfter(now) && available > 0 && c['code'] is String) {
      list.add(RefundCoupon(code: c['code'] as String, availablePaise: available, expires: expires));
    }
  }
  return store.previewFeatures && list.isEmpty ? _samples : list;
});

final _samples = [
  RefundCoupon(code: 'WK-SAMPLE01-REVIEW00', availablePaise: 7900, expires: DateTime.now().add(const Duration(days: 300)), sample: true),
  RefundCoupon(code: 'WK-SAMPLE02-REVIEW00', availablePaise: 14900, expires: DateTime.now().add(const Duration(days: 200)), sample: true),
  RefundCoupon(code: 'WK-SAMPLE03-REVIEW00', availablePaise: 5000, expires: DateTime.now().add(const Duration(days: 90)), sample: true),
];

class CouponPicker extends StatefulWidget {
  const CouponPicker({super.key, required this.onBusy});

  /// Tells Check and pay when a coupon is being checked (Pay waits).
  final ValueChanged<bool> onBusy;

  @override
  State<CouponPicker> createState() => _CouponPickerState();
}

class _CouponPickerState extends State<CouponPicker> {
  late final Stream<List<RefundCoupon>> _coupons = usableCoupons(context.store);
  String? _applying, _error, _sampleApplied;

  bool _isApplied(RefundCoupon c) {
    final d = context.store.draft;
    return c.sample ? _sampleApplied == c.code : d.couponAppliedPaise > 0 && d.couponCode == c.code;
  }

  Future<void> _apply(RefundCoupon c) async {
    if (_applying != null) return;
    final store = context.store;
    if (c.sample) {
      setState(() {
        _sampleApplied = c.code;
        _error = null;
      });
      return;
    }
    setState(() {
      _applying = c.code;
      _error = null;
    });
    widget.onBusy(true);
    try {
      await store.applyCoupon(c.code);
    } catch (e) {
      if (mounted) setState(() => _error = backendError(e));
    } finally {
      widget.onBusy(false);
      if (mounted) setState(() => _applying = null);
    }
  }

  void _remove(RefundCoupon c) {
    if (c.sample) {
      setState(() => _sampleApplied = null);
      return;
    }
    final store = context.store, d = store.draft;
    store.set(() {
      d.couponCode = '';
      d.couponAppliedPaise = 0;
      d.couponVehicleKind = null;
      d.couponBasePricePaise = null;
      d.couponForfeitPaise = 0;
      d.couponForfeitAccepted = false;
    });
  }

  Widget _card(RefundCoupon c, {VoidCallback? afterApply}) => _CouponCard(
    coupon: c,
    applied: _isApplied(c),
    loading: _applying == c.code,
    enabled: _applying == null,
    onApply: () async {
      await _apply(c);
      if (_isApplied(c)) afterApply?.call();
    },
    onRemove: () => _remove(c),
  );

  Future<void> _openSheet(List<RefundCoupon> coupons) async {
    await showWSheet<void>(
      context,
      height: 560,
      builder: (sheetContext) => AppScope(
        store: context.store,
        router: context.router,
        child: StatefulBuilder(
          builder: (sheetContext, setSheet) => ListenableBuilder(
            listenable: context.store,
            builder: (_, _) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const WText('Discount coupons', WType.section, weight: FontWeight.w600),
                  const SizedBox(height: 4),
                  WText('${coupons.length} available · one per wash', WType.caption),
                  const SizedBox(height: 16),
                  for (final c in coupons) ...[
                    _CouponCard(
                      coupon: c,
                      applied: _isApplied(c),
                      loading: _applying == c.code,
                      enabled: _applying == null,
                      onApply: () async {
                        setSheet(() {});
                        await _apply(c);
                        setSheet(() {});
                        if (_isApplied(c) && sheetContext.mounted) {
                          // Let the tick land, then close.
                          await Future<void>.delayed(const Duration(milliseconds: 450));
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        }
                      },
                      onRemove: () {
                        _remove(c);
                        setSheet(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_error != null) WBanner(tone: Tone.error, icon: WIcon.info, text: _error!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final d = context.store.draft;
    return StreamBuilder<List<RefundCoupon>>(
      stream: _coupons,
      builder: (context, snap) {
        final coupons = snap.data ?? const <RefundCoupon>[];
        if (coupons.isEmpty) return const SizedBox.shrink();
        final applied = coupons.where(_isApplied).firstOrNull;
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (coupons.length >= 3)
                applied != null
                    ? _card(applied)
                    : _CouponsButton(
                        count: coupons.length,
                        best: coupons.map((c) => c.availablePaise).reduce((a, b) => a > b ? a : b),
                        onTap: () => _openSheet(coupons),
                      )
              else
                for (final (i, c) in coupons.indexed) ...[if (i > 0) const SizedBox(height: 10), _card(c)],
              if (coupons.length >= 3 && applied != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: WButton('See all ${coupons.length} coupons', kind: ButtonKind.text, onTap: () => _openSheet(coupons)),
                ),
              ],
              if (d.couponForfeitPaise > 0) ...[
                const SizedBox(height: 10),
                WBanner(
                  tone: Tone.wait,
                  icon: WIcon.info,
                  text: 'Single-use coupon: the unused ${Fmt.rupees(d.couponForfeitPaise / 100)} will be lost when payment is confirmed.',
                ),
              ],
              if (_error != null && coupons.length < 3) ...[const SizedBox(height: 10), WBanner(tone: Tone.error, icon: WIcon.info, text: _error!)],
              if (applied?.sample == true) ...[const SizedBox(height: 8), const WText('Sample coupon (review tools) — the price is not changed.', WType.small)],
            ],
          ),
        );
      },
    );
  }
}

class _CouponsButton extends StatelessWidget {
  const _CouponsButton({required this.count, required this.best, required this.onTap});
  final int count, best;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => WCard(
    radius: 16,
    outlined: true,
    onTap: onTap,
    child: Row(
      children: [
        const WIconBox(WIcon.gift, size: 44, tone: Tone.ok),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [const WText('Discount coupons', WType.bodyStrong), WText('$count available · up to ${Fmt.rupees(best / 100)} off', WType.caption)],
          ),
        ),
        const WIconView(WIcon.chevron, size: 13, color: WColor.secondary),
      ],
    ),
  );
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon, required this.applied, required this.loading, required this.enabled, required this.onApply, required this.onRemove});
  final RefundCoupon coupon;
  final bool applied, loading, enabled;
  final VoidCallback onApply, onRemove;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 260);
    final expires = coupon.expires;
    return Semantics(
      label: '${Fmt.rupees(coupon.availablePaise / 100)} coupon${applied ? ', applied' : ''}',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: applied ? WColor.successTint : WColor.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: applied ? WColor.success : WColor.divider, width: applied ? 1.6 : 1),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: duration,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: applied ? WColor.white : WColor.primaryTint, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: WIconView(WIcon.gift, size: 20, color: applied ? WColor.onSuccess : WColor.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WText('${Fmt.rupees(coupon.availablePaise / 100)} off', WType.title, color: applied ? WColor.onSuccess : null),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: duration,
                        child: WText(
                          applied
                              ? 'Applied to this wash'
                              : 'Refund coupon${expires == null ? '' : ' · valid until ${Fmt.date(expires)}${expires.year == DateTime.now().year ? '' : ' ${expires.year}'}'}',
                          WType.caption,
                          key: ValueKey(applied),
                          color: applied ? WColor.onSuccess : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: duration,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: child),
                  ),
                  child: applied
                      ? Pressable(
                          key: const ValueKey('remove'),
                          label: 'Remove coupon',
                          onTap: onRemove,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                            child: WText('Remove', WType.bodyStrong, color: WColor.onSuccess),
                          ),
                        )
                      : Pressable(
                          key: const ValueKey('apply'),
                          label: 'Apply coupon',
                          onTap: enabled ? onApply : null,
                          child: AnimatedContainer(
                            duration: duration,
                            height: 36,
                            constraints: const BoxConstraints(minWidth: 76),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: enabled || loading ? WColor.primary : WColor.divider, borderRadius: BorderRadius.circular(18)),
                            child: loading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: WColor.white))
                                : const WText('Apply', WType.bodyStrong, color: WColor.white),
                          ),
                        ),
                ),
              ],
            ),
          ),
          // The tick pops in at the top-right corner when applied.
          Positioned(
            top: -8,
            right: -6,
            child: AnimatedScale(
              scale: applied ? 1 : 0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: WColor.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: WColor.white, width: 2),
                ),
                alignment: Alignment.center,
                child: const WIconView(WIcon.check, size: 14, color: WColor.white, weight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
