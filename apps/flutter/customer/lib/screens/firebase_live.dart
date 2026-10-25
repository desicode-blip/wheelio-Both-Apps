import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';
import '../data/store.dart';
import '../data/refund_status.dart';

/// Live data behind the booking, tracking, photo review and refund layouts.
class FirebaseOrderScreen extends StatefulWidget {
  const FirebaseOrderScreen({super.key, this.orderId});
  final String? orderId;
  @override
  State<FirebaseOrderScreen> createState() => _FirebaseOrderScreenState();
}

class _FirebaseOrderScreenState extends State<FirebaseOrderScreen> {
  final backend = WashKrewRuntime.backend!;
  bool busy = false, reporting = false, cancelling = false;
  String error = '', note = '', kind = 'notClean';
  int stars = 5, side = 0;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = backendError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget button(
    String label,
    Future<void> Function() action, {
    bool secondary = false,
    bool green = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: WButton(
      busy ? 'Please wait…' : label,
      enabled: !busy,
      kind: secondary
          ? ButtonKind.outline
          : green
          ? ButtonKind.success
          : ButtonKind.primary,
      onTap: () => run(action),
    ),
  );
  Future<void> invoke(
    String method,
    String id, [
    Map<String, dynamic> data = const {},
  ]) async {
    await backend.call(method, {'orderId': id, ...data});
  }

  String money(dynamic value) =>
      Fmt.rupees(((value as num?) ?? 0).toInt() ~/ 100);
  @override
  Widget build(BuildContext context) {
    final router = context.router,
        id = widget.orderId ?? context.store.currentOrderId;
    if (id == null) {
      return WScreen(
        children: [
          const WTitleBlock('No booking selected'),
          button('Go home', () async {
            router.popToRoot();
          }),
        ],
      );
    }
    return StreamBuilder(
      stream: backend.db.doc('orders/$id').snapshots(),
      builder: (context, snapshot) {
        final o = snapshot.data?.data();
        final status = o?['status'];
        final upcoming = ['searching','onTheWay'].contains(status) && (o?['slotStart']?.toDate() as DateTime?)?.isAfter(DateTime.now()) == true;
        final refund = refundStatusText(o?['refundStatus'], o?['refundIssue']);
        final step = switch (status) {
          'onTheWay' => 1,
          'washing' => 2,
          'photosReady' || 'approved' || 'disputed' => 3,
          _ => 0,
        };
        return WScreen(
          canvas: true,
          header: WAppBar(onLeading: router.popToRoot),
          children: [
            if (error.isNotEmpty)
              WBanner(tone: Tone.error, icon: WIcon.close, text: error),
            if (snapshot.hasError)
              const WTitleBlock(
                'Booking unavailable',
                subtitle: 'Check your connection and reopen this booking.',
              )
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (o == null)
              const WTitleBlock('Booking not found')
            else ...[
              if ((o['paymentMode'] ?? 'test') == 'test') ...[
                const WBadge('Test booking · no real payment', tone: Tone.wait, icon: WIcon.rupee),
                const Gap(12),
              ],
              WTitleBlock(upcoming ? 'Booked' : switch (status) {
                'pendingPayment' => 'Complete your payment',
                'searching' => 'Finding a captain',
                'onTheWay' => o['arrivedAt'] != null ? 'Captain has arrived' : 'Captain on the way',
                'washing' => 'Your vehicle is being washed',
                'photosReady' => 'Check your wash',
                'approved' => 'Wash approved',
                'cancelled' => 'Booking cancelled',
                'disputed' => 'Problem under review',
                _ => 'Your booking',
              }, subtitle: '${o['plate']} · ${o['vehicleName']}'),
              WCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WText(o['ref'], WType.label),
                    WText('${o['societyName']} · ${o['tower']}', WType.title),
                    WText(
                      'Floor ${o['floor']} · Parking ${o['parking']}',
                      WType.body,
                    ),
                    WText(
                      '${o['day']} · ${o['startHour']}:00 – ${o['endHour']}:00',
                      WType.caption,
                    ),
                    const Gap(12),
                    WText(
                      '${money(o['pricePaise'])} · ${o['paymentStatus'] == 'captured' ? 'Payment received' : 'Payment not confirmed'}',
                      WType.bodyStrong,
                    ),
                    if (o['captain'] != null)
                      WText('Captain: ${o['captain']['name']}', WType.body),
                  ],
                ),
              ),
              const Gap(24),
              if (!upcoming && !['cancelled', 'pendingPayment'].contains(status))
                WStatusSteps(
                  steps: [
                    const ('Booked', null),
                    (o['arrivedAt'] != null ? 'Captain arrived' : 'Captain on the way', null),
                    const ('Washing', null),
                    const ('Check photos', null),
                  ],
                  current: step,
                ),
              if (upcoming) ...[
                const WText('Your booking is scheduled. Live wash progress opens when the confirmed window starts.', WType.body),
                for(final path in (o['customerPhotos'] as Map? ?? {}).values) PrivatePhoto(path),
              ],
              if (status == 'searching' && !upcoming)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: WText(
                    'An approved captain in your society can accept this paid booking. This screen updates automatically.',
                    WType.body,
                  ),
                ),
              if (status == 'pendingPayment') ...[
                button('Continue to Razorpay', () async {
                  await backend.pay(id);
                }, green: true),
                button('Check payment status', () async {
                  await backend.call('checkPayment', {'bookingId': id});
                }, secondary: true),
              ],
              if (!upcoming && ['onTheWay', 'washing'].contains(status)) ...[
                const Gap(16),
                CaptainTracking(id),
              ],
              if (['photosReady', 'approved', 'disputed'].contains(status)) ...[
                const Gap(24),
                const WText('Before and after photos', WType.section),
                const Gap(12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var i = 0; i < 4; i++)
                      ChoiceChip(
                        label: Text(['Front', 'Back', 'Left', 'Right'][i]),
                        selected: side == i,
                        onSelected: (_) => setState(() => side = i),
                      ),
                  ],
                ),
                for (final stage in ['before', 'after']) ...[
                  const Gap(12),
                  WText(
                    stage == 'before' ? 'Before wash' : 'After wash',
                    WType.label,
                  ),
                  if (o['evidence']?['${stage}_$side']?['path'] != null)
                    PrivatePhoto(o['evidence']['${stage}_$side']['path'])
                  else
                    const WText('Photo unavailable', WType.caption),
                ],
              ],
              for(final media in (o['customerMedia'] as Map? ?? {}).values) PrivateMedia(Map<String,dynamic>.from(media),key:ValueKey(media['path'])),
              if (status == 'photosReady') ...[
                button(
                  'Approve wash',
                  () => invoke('approveWash', id),
                  green: true,
                ),
                const Gap(8),
                const WText(
                  'Your approval confirms the work and approves the captain’s earnings.',
                  WType.caption,
                ),
              ],
              if (status == 'approved') ...[
                const Gap(16),
                const WBanner(
                  tone: Tone.ok,
                  icon: WIcon.check,
                  text:
                      'You approved the wash. The captain’s earnings have been updated.',
                ),
                if (o['rating'] == null) ...[
                  const Gap(16),
                  const WText('Rate your wash', WType.title),
                  Wrap(
                    children: [
                      for (var n = 1; n <= 5; n++)
                        IconButton(
                          tooltip: '$n stars',
                          onPressed: () => setState(() => stars = n),
                          icon: Icon(
                            n <= stars ? Icons.star : Icons.star_border,
                            color: WColor.primary,
                          ),
                        ),
                    ],
                  ),
                  button(
                    'Send rating',
                    () => invoke('rateWash', id, {'stars': stars}),
                  ),
                ] else
                  WText('Your rating: ${o['rating']} / 5', WType.body),
              ],
              if (['photosReady', 'approved'].contains(status))
                button('Report a problem', () async {
                  setState(() => reporting = !reporting);
                }, secondary: true),
              if (reporting &&
                  ['photosReady', 'approved'].contains(status)) ...[
                const Gap(16),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  items: const [
                    DropdownMenuItem(
                      value: 'notClean',
                      child: Text('Wash not clean'),
                    ),
                    DropdownMenuItem(
                      value: 'damage',
                      child: Text('Vehicle damage'),
                    ),
                    DropdownMenuItem(
                      value: 'wrongVehicle',
                      child: Text('Wrong vehicle'),
                    ),
                    DropdownMenuItem(
                      value: 'noShow',
                      child: Text('Wash not done'),
                    ),
                  ],
                  onChanged: (v) => setState(() => kind = v!),
                ),
                const Gap(12),
                WTextArea(
                  value: note,
                  placeholder: 'Describe the problem',
                  onChanged: (v) => note = v,
                ),
                button('Send problem for review', () async {
                  await invoke('reportWashProblem', id, {
                    'kind': kind,
                    'note': note,
                  });
                  setState(() => reporting = false);
                }),
              ],
              if (status == 'disputed')
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: WBanner(
                    tone: Tone.wait,
                    icon: WIcon.shield,
                    text:
                        'Your problem is saved for operations review. Captain earnings are on hold.',
                  ),
                ),
              if ([
                'pendingPayment',
                'searching',
                'onTheWay',
              ].contains(status)) ...[
                button('Cancel booking', () async {
                  setState(() => cancelling = !cancelling);
                }, secondary: true),
                if (cancelling) ...[
                  const Gap(12),
                  WText(
                    context.store.orders.where((order) => order.id == id).firstOrNull?.cancellationTerms ?? 'Review the cancellation policy before confirming.',
                    WType.body,
                  ),
                  button(
                    'Confirm cancellation',
                    () => invoke('cancelBooking', id),
                  ),
                ],
              ],
              if (status == 'cancelled') ...[
                if (o['cancellationBenefit'] != null) WText(o['cancellationBenefit']['kind'] == 'freeWash' ? '1 free wash added to your account.' : o['cancellationBenefit']['kind'] == 'credit' ? '${money(o['cancellationBenefit']['creditPaise'])} credit added to your account.' : 'Your reserved free wash or credit was restored.', WType.body),
                WText(
                  o['paymentStatus'] == 'captured' && o['refundStatus'] != 'none'
                      ? '${refund.title} · ${money(o['refundAmountPaise'] ?? o['pricePaise'])}'
                      : o['paymentStatus'] == 'captured' ? 'No cash refund is due under this booking’s policy.' : 'No captured payment for this booking.',
                  WType.body,
                ),
                if (o['providerRefundId'] != null)
                  WText(
                    'Refund reference: ${o['providerRefundId']}',
                    WType.caption,
                  ),
                if (o['paymentStatus'] == 'captured' && o['refundStatus'] != 'none')
                  WText(refund.detail, WType.caption),
                if (o['paymentStatus'] == 'captured' && o['refundStatus'] != 'none' && o['refundStatus'] != null && o['refundStatus'] != 'processed')
                  button('Check refund status', () async {
                    await backend.call('checkPayment', {'bookingId': id});
                  }),
              ],
              button('Go home', () async {
                router.popToRoot();
              }, secondary: true),
            ],
          ],
        );
      },
    );
  }
}

class FirebaseAccountHelp extends StatelessWidget {
  const FirebaseAccountHelp({super.key});
  @override
  Widget build(BuildContext context) => WScreen(
    header: WAppBar(onLeading: context.router.pop),
    children: [
      const WTitleBlock('Your ${Brand.name} account'),
      WText(context.store.customer?.name ?? '', WType.title),
      WText(
        context.store.customer?.phone ??
            'Verify your mobile number to book a wash.',
        WType.body,
      ),
      const Gap(20),
      const WText(
        'Open a booking to track the captain, review photos, cancel before washing, or report a wash problem.',
        WType.body,
      ),
      const Gap(16),
      const WText(
        'Use the form below to request account help from operations.',
        WType.caption,
      ),
      const Gap(20),
      if(context.store.isLoggedIn) const SupportRequestForm(),
      WButton('Go home', onTap: context.router.popToRoot),
    ],
  );
}
