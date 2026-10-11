import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../config/app_config.dart';
import '../data/mock_backend.dart';
import '../data/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Masked one-tap call to the washer (roadmap F13). Numbers stay hidden on
/// both sides; the call goes through the masking provider's virtual number.
Future<void> callWasher(BuildContext context, Order o) async {
  final app = AppScope.read(context);
  await app.device.openExternal(Uri(scheme: 'tel', path: AppConfig.supportPhone));
  if (context.mounted && AppConfig.useMock) {
    showWSnack(context, 'Calling ${o.washer?.name ?? 'washer'} through a masked number');
  }
}

/// Start a new booking for the same vehicle and place (used after cancel / no washer).
void rebookSameVehicle(BuildContext context, Order o, {String to = R.timeSlot}) {
  final app = AppScope.read(context);
  app.draft.startRepeat(Vehicle(id: o.vehicle.id, plate: o.vehicle.plate, type: o.vehicle.type, place: o.place));
  app.draft.note = o.note;
  context.go(to);
}

String get cancellationFeeText =>
    AppConfig.cancellationFeeRupees == null ? '₹[CANCELLATION FEE]' : rupees(AppConfig.cancellationFeeRupees!);

String refundAfterFeeText(int price) =>
    AppConfig.cancellationFeeRupees == null ? '₹[REFUND AMOUNT]' : rupees(price - AppConfig.cancellationFeeRupees!);

// ---------------------------------------------------------------------------
// C20-Searching

class SearchingScreen extends StatelessWidget {
  const SearchingScreen({super.key});

  @override
  Widget build(BuildContext context) => OrderWatcher(
        route: R.searching,
        builder: (context, o) => WScreen(
          header: OrderHeader(order: o),
          children: [
            const SizedBox(height: 8),
            const Center(
              child: SizedBox(
                width: 88,
                height: 88,
                child: CircularProgressIndicator(strokeWidth: 5, backgroundColor: WColors.primaryTint),
              ),
            ),
            Column(
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text('Finding a washer…', style: WText.screen, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 8),
                Text('Usually under 5 minutes. You can leave this screen; we’ll notify you.',
                    style: WText.body, textAlign: TextAlign.center),
              ],
            ),
            Center(
              child: WBadge(
                tone: WTone.ok,
                icon: Icons.verified_user_outlined,
                label: o.usedFreeWash ? 'Free wash' : '${rupees(o.price)} held safely',
              ),
            ),
            WCard(child: WStatusSteps(steps: orderSteps, current: o.status.stepIndex)),
          ],
          footer: WFooterBar(vertical: true, children: [
            WButton(label: 'Keep me posted', onPressed: () => context.go(R.home)),
            WButton.text(label: 'Cancel booking', onPressed: () => context.push(R.cancel)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
// C21-NoWasher

class NoWasherScreen extends StatelessWidget {
  const NoWasherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final o = AppScope.of(context).currentOrder;
    if (o == null) return const NoOrderView();
    return WScreen(
      header: const SimpleHeader(),
      body: WStateView(
        icon: Icons.person_search_outlined,
        tone: WTone.wait,
        title: 'No washer was free',
        body: 'Sorry about that. Your ${rupees(o.price)} is on its way back: 2 to 3 working days to your UPI.',
      ),
      footer: WFooterBar(vertical: true, children: [
        WButton(label: 'Book a later slot', onPressed: () => rebookSameVehicle(context, o)),
        WButton.text(label: 'See refund', onPressed: () => context.push(R.refund)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// C22-OnTheWay, C22b (pass missing), C24 (running late), C30 (can't find vehicle)

class OnTheWayScreen extends StatelessWidget {
  const OnTheWayScreen({super.key});

  @override
  Widget build(BuildContext context) => OrderWatcher(
        route: R.onTheWay,
        builder: (context, o) => o.washerCantFind ? _CantFindView(order: o) : _OnTheWayView(order: o),
      );
}

class _OnTheWayView extends StatelessWidget {
  const _OnTheWayView({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final washer = o.washer ?? MockBackend.raju;
    final lateBy = o.runningLateBy;
    final arrives = o.arrivesBy ?? o.slot.start;
    final refundIfNotStartedBy = o.slot.end.add(const Duration(minutes: 30));
    return WScreen(
      header: OrderHeader(order: o),
      children: [
        WasherCard(
          washer: washer,
          badge: lateBy == null
              ? const WBadge(tone: WTone.ok, icon: Icons.check_circle_outline_rounded, label: 'Accepted')
              : const WBadge(tone: WTone.wait, icon: Icons.schedule_rounded, label: 'Running late'),
          detail: lateBy == null ? 'Arrives by ${formatTime(arrives)}' : 'Now arriving ${formatTime(arrives.add(lateBy))}',
        ),
        if (lateBy != null)
          WBanner(
            tone: WTone.wait,
            text: '${washer.name} is running about ${lateBy.inMinutes} minutes late. '
                'If the wash doesn’t start by ${formatTime(refundIfNotStartedBy)} you get a full refund.',
          )
        else if (o.entryPassReceived)
          WBanner(tone: WTone.ok, icon: Icons.badge_outlined, text: 'Entry pass received. ${washer.name} can get in.')
        else
          WBanner(
            tone: WTone.wait,
            icon: Icons.badge_outlined,
            text: 'We still need your gate pass. Without it ${washer.name} may be stopped at the gate.',
            action: WLinkButton(label: 'Send now', onTap: () => context.push(R.whatsApp)),
          ),
        WCard(child: WStatusSteps(steps: orderSteps, current: o.status.stepIndex)),
      ],
      footer: WFooterBar(
        vertical: true,
        children: [
          if (lateBy != null)
            WButton(icon: Icons.phone_outlined, label: 'Call ${washer.name}', onPressed: () => callWasher(context, o))
          else if (!o.entryPassReceived)
            WButton(icon: Icons.chat_outlined, label: 'Send pass on WhatsApp', onPressed: () => context.push(R.whatsApp))
          else
            WButton(
              variant: WButtonVariant.tonal,
              icon: Icons.chat_outlined,
              label: 'Message on WhatsApp',
              onPressed: () => context.push(R.whatsApp),
            ),
          WButton.text(label: 'Cancel booking', onPressed: () => context.push(R.cancel)),
        ],
      ),
    );
  }
}

class _CantFindView extends StatefulWidget {
  const _CantFindView({required this.order});

  final Order order;

  @override
  State<_CantFindView> createState() => _CantFindViewState();
}

class _CantFindViewState extends State<_CantFindView> {
  bool _sending = false;

  Future<void> _answer(String answer) async {
    final app = AppScope.read(context);
    if (answer == 'different_floor') {
      final floor = await showWSheet<String>(
        context,
        builder: (context) => WGap(
          gap: 12,
          children: [
            Text('Which floor is it on?', style: WText.section),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final f in const ['B3', 'B2', 'B1', 'Ground', 'Open'])
                WChoiceChip(label: f, selected: false, onTap: () => Navigator.of(context).pop(f)),
            ]),
          ],
        ),
      );
      if (floor == null) return;
      answer = 'floor:$floor';
    }
    setState(() => _sending = true);
    await guarded(context, () => app.backend.answerCantFind(widget.order.id, answer));
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final washer = o.washer ?? MockBackend.raju;
    return WScreen(
      header: OrderHeader(order: o),
      children: [
        WBanner(
          tone: WTone.wait,
          icon: Icons.search_off_rounded,
          title: '${washer.name} can’t find your vehicle',
          text: 'He’s at ${o.place.floor ?? 'the parking'} near slot ${o.place.slot.isEmpty ? '—' : o.place.slot} '
              'and doesn’t see ${o.vehicle.plate}. Is it parked somewhere else today?',
        ),
        WGap(children: [
          WSelectionTile(
            icon: Icons.layers_outlined,
            title: 'It’s on a different floor',
            selected: false,
            onTap: _sending ? null : () => _answer('different_floor'),
          ),
          WSelectionTile(
            icon: Icons.local_parking_rounded,
            title: 'I moved it outside',
            selected: false,
            onTap: _sending ? null : () => _answer('outside'),
          ),
          WSelectionTile(
            icon: Icons.do_not_disturb_on_outlined,
            title: 'It’s not here today',
            selected: false,
            onTap: _sending ? null : () => _answer('not_here'),
          ),
        ]),
      ],
      footer: WFooterBar(children: [
        WButton(icon: Icons.phone_outlined, label: 'Call ${washer.name}', onPressed: () => callWasher(context, o)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// C23-Washing

class WashingScreen extends StatelessWidget {
  const WashingScreen({super.key});

  @override
  Widget build(BuildContext context) => OrderWatcher(
        route: R.washing,
        builder: (context, o) {
          final washer = o.washer ?? MockBackend.raju;
          return WScreen(
            header: OrderHeader(order: o),
            children: [
              WasherCard(
                washer: washer,
                badge: const WBadge(tone: WTone.info, icon: Icons.water_drop_outlined, label: 'Cleaning'),
                detail: 'Started ${formatTime(o.startedAt ?? DateTime.now())}',
              ),
              WCard(
                child: WGap(
                  gap: 12,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Before photos', style: WText.title)),
                        WBadge(tone: WTone.ok, label: '${o.beforePhotos} of 4'),
                      ],
                    ),
                    Row(
                      children: [
                        for (final a in const [PhotoAngle.front, PhotoAngle.left]) ...[
                          if (a != PhotoAngle.front) const SizedBox(width: 10),
                          Expanded(child: WPhotoSlot(label: a.label, state: WPhotoState.filled, tag: WPhotoTag.before)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              WCard(child: WStatusSteps(steps: orderSteps, current: o.status.stepIndex)),
            ],
            footer: WFooterBar(
              leading: supportButton(context),
              children: [
                WButton(
                  variant: WButtonVariant.outline,
                  icon: Icons.phone_outlined,
                  label: 'Call ${washer.name}',
                  onPressed: () => callWasher(context, o),
                ),
              ],
            ),
          );
        },
      );
}

// ---------------------------------------------------------------------------
// C25-CheckPhotos

class CheckPhotosScreen extends StatefulWidget {
  const CheckPhotosScreen({super.key});

  @override
  State<CheckPhotosScreen> createState() => _CheckPhotosScreenState();
}

class _CheckPhotosScreenState extends State<CheckPhotosScreen> {
  bool _approving = false;

  @override
  Widget build(BuildContext context) => OrderWatcher(
        route: R.checkPhotos,
        builder: (context, o) {
          final washer = o.washer ?? MockBackend.raju;
          Widget pair(PhotoAngle a) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.label, style: WText.label),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: WPhotoSlot(
                        label: a.label,
                        state: WPhotoState.filled,
                        tag: WPhotoTag.before,
                        onTap: () => context.push('${R.photoCompare}?angle=${a.name}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: WPhotoSlot(
                        label: a.label,
                        state: WPhotoState.filled,
                        tag: WPhotoTag.after,
                        onTap: () => context.push('${R.photoCompare}?angle=${a.name}'),
                      ),
                    ),
                  ]),
                ],
              );
          return WScreen(
            header: WHeader(
              appBar: WAppBar(
                title: 'Check the wash',
                subtitle: '${washer.name} finished at ${formatTime(o.finishedAt ?? DateTime.now())}',
                onBack: () => context.go(R.home),
                backIcon: Icons.close_rounded,
                backLabel: 'Close',
                onHelp: () => openHelp(context),
              ),
            ),
            children: [
              WBanner(
                tone: WTone.ok,
                icon: Icons.auto_awesome_outlined,
                title: 'Shine restored',
                text: o.usedFreeWash
                    ? 'Approve to finish this free wash'
                    : 'Approve to release ${rupees(o.price)} to ${washer.name}',
              ),
              pair(PhotoAngle.front),
              pair(PhotoAngle.left),
              Align(
                alignment: Alignment.centerLeft,
                child: WLinkButton(label: 'See all 4 angles', onTap: () => context.push(R.photoCompare)),
              ),
              Text(
                'Auto-approves at ${formatTime(o.autoApproveAt ?? DateTime.now().add(AppConfig.approvalWindow))} '
                'if we don’t hear from you.',
                style: WText.caption,
              ),
            ],
            footer: WFooterBar(vertical: true, children: [
              WButton(
                variant: WButtonVariant.success,
                label: 'Approve and pay',
                loading: _approving,
                onPressed: () async {
                  setState(() => _approving = true);
                  await guarded(context, () => AppScope.read(context).backend.approve(o.id));
                  if (mounted) setState(() => _approving = false);
                },
              ),
              WButton.text(label: 'Something’s wrong', onPressed: () => context.push(R.reportProblem)),
            ]),
          );
        },
      );
}

// ---------------------------------------------------------------------------
// C26-PhotoCompare

class PhotoCompareScreen extends StatefulWidget {
  const PhotoCompareScreen({super.key, this.angle = PhotoAngle.front});

  final PhotoAngle angle;

  @override
  State<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends State<PhotoCompareScreen> {
  late final PageController _pages = PageController(initialPage: PhotoAngle.values.indexOf(widget.angle));
  late int _index = PhotoAngle.values.indexOf(widget.angle);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = AppScope.of(context).currentOrder;
    if (o == null) return const NoOrderView();
    final started = o.startedAt ?? DateTime.now();
    final finished = o.finishedAt ?? DateTime.now();
    return WScreen(
      header: WHeader(
        appBar: WAppBar(
          title: '${PhotoAngle.values[_index].label} · ${_index + 1} of 4',
          onBack: () => goBack(context, R.checkPhotos),
          trailing: WIconButton(
            icon: Icons.flag_outlined,
            label: 'Report a problem',
            style: WIconButtonStyle.flat,
            onPressed: () => context.push(R.reportProblem),
          ),
        ),
      ),
      body: PageView(
        controller: _pages,
        onPageChanged: (i) => setState(() => _index = i),
        children: [
          for (final a in PhotoAngle.values)
            ListView(
              padding: const EdgeInsets.fromLTRB(WSpace.gutter, 16, WSpace.gutter, 16),
              children: [
                WPhotoSlot(label: a.label, state: WPhotoState.filled, tag: WPhotoTag.before),
                const SizedBox(height: 6),
                Text('Before · ${formatTime(started.add(const Duration(minutes: 1)))}', style: WText.caption),
                const SizedBox(height: 16),
                WPhotoSlot(label: a.label, state: WPhotoState.filled, tag: WPhotoTag.after),
                const SizedBox(height: 6),
                Text('After · ${formatTime(finished.subtract(const Duration(minutes: 1)))}', style: WText.caption),
              ],
            ),
        ],
      ),
      footer: o.status == OrderStatus.photosReady
          ? WFooterBar(children: [
              WButton(
                variant: WButtonVariant.success,
                label: 'Approve',
                onPressed: () async {
                  final approved = await guarded(context, () => AppScope.read(context).backend.approve(o.id));
                  if (approved != null && context.mounted) {
                    AppScope.read(context).setOrder(approved);
                    context.go(R.rate);
                  }
                },
              ),
            ])
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// C27-Rate

class RateScreen extends StatefulWidget {
  const RateScreen({super.key});

  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  static const goodTags = ['Spotless', 'On time', 'Polite'];
  static const badTags = ['Missed a spot', 'Late'];
  int _stars = 0;
  final Set<String> _tags = {};
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final o = AppScope.of(context).currentOrder;
    if (o == null) return const NoOrderView();
    final washer = o.washer ?? MockBackend.raju;
    return WScreen(
      header: WHeader(
        appBar: WAppBar(
          trailing: WIconButton(
            icon: Icons.close_rounded,
            label: 'Skip rating',
            style: WIconButtonStyle.flat,
            onPressed: () => context.go(R.home),
          ),
        ),
      ),
      children: [
        Center(child: WAvatar(initials: washer.initials, size: 72)),
        Column(children: [
          Semantics(header: true, child: Text('How did ${washer.name} do?', style: WText.screen, textAlign: TextAlign.center)),
          const SizedBox(height: 8),
          Text(
            o.usedFreeWash
                ? 'Thanks for approving.'
                : '${rupees(o.price)} released to ${washer.name}. Thanks for approving.',
            style: WText.body,
            textAlign: TextAlign.center,
          ),
        ]),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i star${i == 1 ? '' : 's'}',
                iconSize: 44,
                onPressed: () => setState(() => _stars = i),
                icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= _stars ? const Color(0xFFF5A623) : WColors.muted),
              ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final t in [...goodTags, ...badTags])
              WChoiceChip(
                label: t,
                selected: _tags.contains(t),
                onTap: () => setState(() => _tags.contains(t) ? _tags.remove(t) : _tags.add(t)),
              ),
          ],
        ),
      ],
      footer: WFooterBar(children: [
        WButton(
          label: 'Submit',
          loading: _sending,
          onPressed: _stars == 0
              ? null
              : () async {
                  setState(() => _sending = true);
                  await guarded(context, () => AppScope.read(context).backend.rate(o.id, _stars, _tags.toList()));
                  if (context.mounted) {
                    showWSnack(context, 'Thanks. Your rating helps ${washer.name} keep their level.');
                    context.go(R.home);
                  }
                },
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// C28-AutoApproved

class AutoApprovedScreen extends StatelessWidget {
  const AutoApprovedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final o = AppScope.of(context).currentOrder;
    if (o == null) return const NoOrderView();
    final washer = o.washer ?? MockBackend.raju;
    final until = (o.finishedAt ?? DateTime.now()).add(AppConfig.approvalWindow).add(AppConfig.disputeWindow);
    return WScreen(
      header: const SimpleHeader(fallback: R.bookings),
      body: WStateView(
        icon: Icons.task_alt_rounded,
        tone: WTone.ok,
        title: 'Approved automatically',
        body: 'We didn’t hear from you within ${AppConfig.approvalWindow.inHours} hours, so the wash was approved '
            'and ${rupees(o.price)} went to ${washer.name}. Something wrong? You can still report it until '
            '${formatTime(until)} ${formatDay(until).toLowerCase() == 'tomorrow' ? 'tomorrow' : formatDate(until)}.',
      ),
      footer: WFooterBar(vertical: true, children: [
        WButton(label: 'Rate ${washer.name}', onPressed: () => context.go(R.rate)),
        WButton.text(label: 'Report a problem', onPressed: () => context.push(R.reportProblem)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// C29-CancelSheet, C29c (after washer accepted)

class CancelScreen extends StatefulWidget {
  const CancelScreen({super.key});

  @override
  State<CancelScreen> createState() => _CancelScreenState();
}

class _CancelScreenState extends State<CancelScreen> {
  static const reasons = ['Changed plans', 'Booked by mistake', 'Taking too long', 'Other'];
  String? _reason;
  bool _cancelling = false;

  Future<void> _cancel(Order o) async {
    setState(() => _cancelling = true);
    final app = AppScope.read(context);
    final result = await guarded(context, () => app.backend.cancelOrder(o.id, reason: _reason));
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (result != null) {
      app.setOrder(result);
      context.go(R.cancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = AppScope.of(context).currentOrder;
    if (o == null) return const NoOrderView();
    final accepted = o.status == OrderStatus.onTheWay;
    final washer = o.washer ?? MockBackend.raju;
    return WScreen(
      background: WColors.canvas,
      header: OrderHeader(order: o, onBack: () => goBack(context, liveRouteFor(o))),
      children: [
        WCard(
          style: WCardStyle.raised,
          padding: const EdgeInsets.all(24),
          child: WGap(
            gap: 16,
            children: [
              Text(accepted ? '${washer.name} is already on the way' : 'Cancel this wash?', style: WText.section),
              Text(
                accepted
                    ? 'Cancelling now refunds ${refundAfterFeeText(o.price)}. $cancellationFeeText goes to ${washer.name} for the trip.'
                    : 'No washer has accepted yet, so you get the full ${rupees(o.price)} back.',
                style: WText.body,
              ),
              if (!accepted) ...[
                Text('Why are you cancelling? (optional)', style: WText.label),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final r in reasons)
                    WChoiceChip(label: r, selected: _reason == r, onTap: () => setState(() => _reason = r)),
                ]),
              ],
            ],
          ),
        ),
      ],
      footer: WFooterBar(vertical: true, children: [
        WButton(
          variant: WButtonVariant.danger,
          label: accepted ? 'Cancel anyway' : 'Yes, cancel and refund',
          loading: _cancelling,
          onPressed: () => _cancel(o),
        ),
        WButton.text(label: 'Keep booking', onPressed: () => goBack(context, liveRouteFor(o))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// C29b-Cancelled

class CancelledScreen extends StatelessWidget {
  const CancelledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final o = AppScope.of(context).currentOrder;
    if (o == null) return const NoOrderView();
    final amount = o.refund?.amount ?? o.price;
    return WScreen(
      header: const SimpleHeader(),
      body: WStateView(
        icon: Icons.event_busy_outlined,
        tone: WTone.mute,
        title: 'Booking cancelled',
        body: '${rupees(amount)} is on its way back to your UPI. It usually takes 2 to 3 working days.',
      ),
      footer: WFooterBar(vertical: true, children: [
        WButton(label: 'Book another time', onPressed: () => rebookSameVehicle(context, o)),
        WButton.text(label: 'Track refund', onPressed: () => context.push(R.refund)),
      ]),
    );
  }
}
