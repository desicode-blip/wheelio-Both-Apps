import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/mock_backend.dart';
import '../data/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Kind chosen on C31, carried to C32.
ProblemKind? _pendingKind;

// ---------------------------------------------------------------------------
// C31-ReportProblem

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  ProblemKind? _kind = _pendingKind;

  IconData _icon(ProblemKind k) => switch (k) {
        ProblemKind.notClean => Icons.water_drop_outlined,
        ProblemKind.damage => Icons.car_crash_outlined,
        ProblemKind.wrongVehicle => Icons.no_crash_outlined,
        ProblemKind.noShow => Icons.person_off_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return WScreen(
      header: WHeader(
        appBar: WAppBar(
          title: 'Report a problem',
          onBack: () => goBack(context, R.checkPhotos),
          onHelp: () => openHelp(context),
        ),
        progress: const WProgress(step: 1, total: 2, label: 'What happened'),
      ),
      children: [
        const WTitleBlock(title: 'What went wrong?', subtitle: 'Payment stays on hold while we check.'),
        WGap(children: [
          for (final k in ProblemKind.values)
            WSelectionTile(
              icon: _icon(k),
              title: k.title,
              subtitle: k.subtitle,
              selected: _kind == k,
              onTap: () => setState(() => _kind = k),
            ),
        ]),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          WButton(
            label: 'Next',
            onPressed: _kind == null
                ? null
                : () {
                    _pendingKind = _kind;
                    context.push(R.problemPhotos);
                  },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C32-ProblemPhotos

class ProblemPhotosScreen extends StatefulWidget {
  const ProblemPhotosScreen({super.key});

  @override
  State<ProblemPhotosScreen> createState() => _ProblemPhotosScreenState();
}

class _ProblemPhotosScreenState extends State<ProblemPhotosScreen> {
  final _note = TextEditingController();
  final List<String> _photos = [];
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final device = AppScope.read(context).device;
    if (!await device.ensureCamera()) {
      if (mounted) showWSnack(context, 'Allow camera in Settings to add photos');
      return;
    }
    final path = await device.takePhoto();
    if (path != null && mounted) setState(() => _photos.add(path));
  }

  Future<void> _send() async {
    final app = AppScope.read(context);
    final o = app.currentOrder;
    if (o == null) return;
    setState(() => _sending = true);
    final d = await guarded(
      context,
      () => app.backend.reportProblem(o.id, _pendingKind ?? ProblemKind.notClean,
          note: _note.text.trim(), photoCount: _photos.length),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (d != null) {
      _pendingKind = null;
      app.setOrder(await app.backend.getOrder(o.id));
      if (mounted) context.go(d.outcome == DisputeOutcome.damagePriority ? R.disputeDecision : R.disputeSent);
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Front', 'Close-up'];
    return WScreen(
      header: WHeader(
        appBar: WAppBar(
          title: 'Report a problem',
          onBack: () => goBack(context, R.reportProblem),
          onHelp: () => openHelp(context),
        ),
        progress: const WProgress(step: 2, total: 2, label: 'Show us'),
      ),
      children: [
        const WTitleBlock(
          title: 'Show us the problem',
          subtitle: 'Take photos from the same angles as the washer’s. We compare all three.',
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (var i = 0; i < _photos.length; i++)
              WPhotoSlot(
                label: i < labels.length ? labels[i] : 'Photo ${i + 1}',
                state: WPhotoState.filled,
                tag: WPhotoTag.yours,
                aspectRatio: 1,
                onTap: () => setState(() => _photos.removeAt(i)),
              ),
            if (_photos.length < 6)
              WPhotoSlot(label: 'Add', aspectRatio: 1, icon: Icons.add_a_photo_outlined, onTap: _add),
          ],
        ),
        WTextField(
          label: 'What should we look at?',
          controller: _note,
          hint: 'Water streaks on the bonnet and the left mirror wasn’t wiped.',
          maxLines: 4,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          WButton(label: 'Send report', loading: _sending, onPressed: _photos.isEmpty ? null : _send),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C33-DisputeSent

class DisputeSentScreen extends StatelessWidget {
  const DisputeSentScreen({super.key});

  @override
  Widget build(BuildContext context) => OrderWatcher(
        route: R.disputeSent,
        builder: (context, o) {
          final d = o.dispute;
          final created = d?.createdAt ?? DateTime.now();
          final decisionBy = created.add(const Duration(hours: 24));
          Widget step(IconData icon, String title, String sub, WTone tone) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WIconTile(icon: icon, size: 40, tone: tone),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(title, style: WText.title), Text(sub, style: WText.caption)],
                      ),
                    ),
                  ],
                ),
              );
          return WScreen(
            header: WHeader(
              appBar: WAppBar(
                title: 'Report sent',
                onBack: () => context.go(R.home),
                backIcon: Icons.close_rounded,
                backLabel: 'Close',
                onHelp: () => openHelp(context),
              ),
            ),
            children: [
              Row(children: [
                const WBadge(tone: WTone.wait, label: 'Under review'),
                const SizedBox(width: 10),
                Text('Ref #${d?.ref ?? o.ref}', style: WText.caption),
              ]),
              WTitleBlock(
                title: 'We’re checking the photos',
                subtitle: '${rupees(o.price)} stays on hold. You’ll hear from us within 24 hours.',
              ),
              WCard(
                child: Column(children: [
                  step(Icons.check_rounded, 'Report received', formatTime(created), WTone.ok),
                  step(Icons.compare_outlined, 'Comparing photos', 'Your photos vs the washer’s before and after', WTone.info),
                  step(Icons.gavel_rounded, 'Decision', 'By ${formatTime(decisionBy)} ${formatDay(decisionBy).toLowerCase()}',
                      WTone.mute),
                ]),
              ),
            ],
            footer: WFooterBar(
              leading: supportButton(context),
              children: [WButton(label: 'Done', onPressed: () => context.go(R.home))],
            ),
          );
        },
      );
}

// ---------------------------------------------------------------------------
// C34-DisputeUpheld, C35-DisputeRejected, C36-DamageReport

class DisputeDecisionScreen extends StatelessWidget {
  const DisputeDecisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final o = AppScope.of(context).currentOrder;
    final d = o?.dispute;
    if (o == null || d == null) return const NoOrderView();
    final washer = o.washer ?? MockBackend.raju;
    final header = WHeader(
      appBar: WAppBar(
        title: d.outcome == DisputeOutcome.damagePriority ? 'Damage report' : 'Report #${d.ref}',
        onBack: () => context.go(R.home),
        backIcon: Icons.close_rounded,
        backLabel: 'Close',
        onHelp: () => openHelp(context),
      ),
    );

    switch (d.outcome) {
      case DisputeOutcome.underReview:
        return const DisputeSentScreen();
      case DisputeOutcome.upheld:
        return WScreen(
          header: header,
          children: [
            const WTitleBlock(title: 'You’re right, sorry'),
            Text('${d.decisionNote} ${washer.name} won’t be paid for this wash.', style: WText.body),
            WCard(
              child: WRowGroup(children: [
                WKeyValue(label: 'Refund', value: '${rupees(o.price)} to your UPI', strong: true),
                WKeyValue(label: 'Bonus', value: '${d.creditsAwarded} free washes added'),
              ]),
            ),
          ],
          footer: WFooterBar(
            leading: supportButton(context),
            children: [
              WButton(
                label: 'Book free wash',
                onPressed: () {
                  final app = AppScope.read(context);
                  app.draft.startRepeat(o.vehicle);
                  app.draft.useFreeWash = true;
                  context.go(R.repeat);
                },
              ),
            ],
          ),
        );
      case DisputeOutcome.rejected:
        return WScreen(
          header: header,
          children: [
            const WTitleBlock(
              title: 'The wash looks complete',
              subtitle: 'We compared your photos with the washer’s. The marks were there before the wash.',
            ),
            Row(children: const [
              Expanded(child: WPhotoSlot(label: 'Before', state: WPhotoState.filled, tag: WPhotoTag.before, aspectRatio: 1)),
              SizedBox(width: 8),
              Expanded(child: WPhotoSlot(label: 'After', state: WPhotoState.filled, tag: WPhotoTag.after, aspectRatio: 1)),
              SizedBox(width: 8),
              Expanded(child: WPhotoSlot(label: 'Yours', state: WPhotoState.filled, tag: WPhotoTag.yours, aspectRatio: 1)),
            ]),
            WBanner(tone: WTone.info, text: d.decisionNote),
            Text('${rupees(o.price)} has been released to the washer.', style: WText.body),
          ],
          footer: WFooterBar(vertical: true, children: [
            WButton(label: 'Okay', onPressed: () => context.go(R.home)),
            WButton.text(label: 'Talk to a person', onPressed: () => openHelp(context)),
          ]),
        );
      case DisputeOutcome.damagePriority:
        Widget item(IconData icon, String title, String? sub) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WIconTile(icon: icon, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(title, style: WText.title), if (sub != null) Text(sub, style: WText.caption)],
                    ),
                  ),
                ],
              ),
            );
        return WScreen(
          header: header,
          children: [
            Row(children: [
              const WBadge(tone: WTone.error, icon: Icons.priority_high_rounded, label: 'Priority'),
              const SizedBox(width: 10),
              Text('Ref #${d.ref}', style: WText.caption),
            ]),
            const WTitleBlock(
              title: 'We’ll call you within 1 hour',
              subtitle: 'A real person from our team will go through this with you.',
            ),
            WCard(
              child: Column(children: [
                item(Icons.pause_circle_outline_rounded, '${washer.name} is paused from new jobs', null),
                item(Icons.folder_zip_outlined, 'Evidence pack ready', 'Time-stamped photos, location and call log'),
                item(Icons.shield_outlined, 'We help with the claim', 'Small damage paid from our protection fund'),
              ]),
            ),
          ],
          footer: WFooterBar(
            leading: supportButton(context),
            children: [
              WButton(
                variant: WButtonVariant.outline,
                icon: Icons.download_rounded,
                label: 'Download evidence pack',
                onPressed: () => showWSnack(context, 'The evidence pack is prepared by the server once connected'),
              ),
            ],
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// C37-RefundStatus

class RefundStatusScreen extends StatelessWidget {
  const RefundStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final o = AppScope.of(context).currentOrder;
    if (o == null) return const NoOrderView();
    final r = o.refund ??
        Refund(amount: o.price, startedAt: DateTime.now(), method: 'Google Pay · ananya@okhdfc', bankRef: 'RZP8812093');
    final expectBy = r.startedAt.add(const Duration(days: 4));
    Widget step(bool done, bool current, String title, String sub) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                done ? Icons.check_circle_rounded : (current ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
                color: done ? WColors.success : (current ? WColors.primary : WColors.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(title, style: WText.title), Text(sub, style: WText.caption)],
                ),
              ),
            ],
          ),
        );
    return WScreen(
      header: WHeader(
        appBar: WAppBar(title: 'Refund', onBack: () => goBack(context, R.bookingDetail), onHelp: () => openHelp(context)),
      ),
      children: [
        WCard(
          style: WCardStyle.fill,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Refund amount', style: WText.label),
              Text(rupees(r.amount), style: WText.bigMoney),
              const SizedBox(height: 8),
              WBadge(
                tone: r.credited ? WTone.ok : WTone.info,
                label: r.credited ? 'Refunded' : 'Refund started',
              ),
            ],
          ),
        ),
        WCard(
          child: Column(children: [
            step(true, false, 'Refund started', '${formatDate(r.startedAt)} · ${formatTime(r.startedAt)}'),
            step(r.credited, !r.credited, 'With your bank', 'Usually 2 to 3 working days'),
            step(r.credited, false, 'In your account', r.method),
          ]),
        ),
        Text('Bank reference: ${r.bankRef}. Not received by ${formatDate(expectBy)}? Call us.', style: WText.caption),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [WButton(label: 'Done', onPressed: () => context.go(R.home))],
      ),
    );
  }
}
