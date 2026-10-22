// Firebase controllers for the existing Captain phone layouts and design system.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';
import 'package:wheelio_firebase/wheelio_firebase.dart';

class FirebaseCaptainScreen extends StatefulWidget {
  const FirebaseCaptainScreen({super.key});
  @override
  State<FirebaseCaptainScreen> createState() => _FirebaseCaptainScreenState();
}

class _FirebaseCaptainScreenState extends State<FirebaseCaptainScreen> {
  final backend = WheelioRuntime.backend!;
  final subscriptions = <StreamSubscription>[];
  final accountSubscriptions = <StreamSubscription>[];
  Map<String, dynamic> config = {}, captain = {};
  List<Map<String, dynamic>> orders = [], offers = [], earnings = [];
  String uid = '', phone = '', name = '', code = '', upi = '', error = '';
  String? selected;
  String? restoredApplication;
  int tab = 0;
  bool busy = false, otpSent = false, loaded = false, sharing = false;
  final selectedSocieties = <String>{}, uploaded = <String>{};
  Timer? tick;
  int seconds = 0;
  @override
  void initState() {
    super.initState();
    subscriptions.add(
      backend.catalog.listen((s) {
        if (mounted) setState(() => config = s.data() ?? {});
      }, onError: showError),
    );
    subscriptions.add(
      backend.sessions.listen((user) {
        final next = user?.phoneNumber != null ? user!.uid : '';
        if (next != uid) bind(next);
      }),
    );
    if (backend.phoneVerified) bind(backend.uid!);
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => seconds++);
      if (seconds % 60 == 0 && captain['online'] == true) {
        backend.call('setCaptainOnline', {'online': true}).catchError((
          Object e,
        ) {
          showError(e);
          return <String, dynamic>{};
        });
      }
      if (seconds % 15 == 0 && sharing && selected != null) {
        backend.shareLocation(selected!).catchError(showError);
      }
    });
  }

  void showError(Object e) {
    if (mounted) setState(() => error = backendError(e));
  }

  void bind(String next) {
    for (final s in accountSubscriptions) {
      s.cancel();
    }
    accountSubscriptions.clear();
    setState(() {
      uid = next;
      captain = {};
      orders = [];
      offers = [];
      earnings = [];
      selected = null;
      sharing = false;
      loaded = next.isEmpty;
      restoredApplication = null;
      uploaded.clear();
      selectedSocieties.clear();
      upi = '';
      error = '';
      if (next.isEmpty) {
        name = '';
        phone = '';
        code = '';
        otpSent = false;
      }
    });
    if (next.isEmpty) return;
    accountSubscriptions.add(
      backend.captain(next).listen((s) {
        if (mounted && uid == next) {
          setState(() {
            captain = s.data() ?? {};
            loaded = true;
            final applicationVersion = '$next:${captain['kycStatus']}';
            if (captain.isNotEmpty && restoredApplication != applicationVersion) {
              restoredApplication = applicationVersion;
              upi = captain['upi'] as String? ?? '';
              selectedSocieties.clear();
              selectedSocieties.addAll((captain['requestedSocietyIds'] as List? ?? []).cast<String>());
              if (['notSubmitted', 'changesRequested'].contains(captain['kycStatus'])) {
                backend.uploadedKyc().then((files) {
                  if (mounted && uid == next) setState(() => uploaded.addAll(files));
                }).catchError((Object e) {
                  if (mounted && uid == next) showError(e);
                });
              }
            }
          });
        }
      }, onError: showError),
    );
    accountSubscriptions.add(
      backend.orders(next, captain: true).listen((s) {
        if (mounted && uid == next) {
          setState(
            () {
              orders = [for (final d in s.docs) {...d.data(), 'id': d.id}];
              if (!orders.any((o)=>o['id']==selected&&['onTheWay','washing'].contains(o['status']))) sharing=false;
            },
          );
        }
      }, onError: showError),
    );
    accountSubscriptions.add(
      backend.offers(next).listen((s) {
        if (mounted && uid == next) {
          setState(
            () => offers = [
              for (final d in s.docs) {...d.data(), 'id': d.id},
            ],
          );
        }
      }, onError: showError),
    );
    accountSubscriptions.add(
      backend.earnings(next).listen((s) {
        if (mounted && uid == next) {
          setState(
            () => earnings = [
              for (final d in s.docs) {...d.data(), 'id': d.id},
            ],
          );
        }
      }, onError: showError),
    );
  }

  @override
  void dispose() {
    tick?.cancel();
    for (final s in [...subscriptions, ...accountSubscriptions]) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await action();
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> invoke(String method, Map<String, dynamic> data) async {
    await backend.call(method, data);
  }

  Widget button(
    String text,
    Future<void> Function() action, {
    bool enabled = true,
    bool secondary = false,
    bool green = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: WButton(
      busy ? 'Please wait…' : text,
      size: ButtonSize.captain,
      enabled: !busy && enabled,
      kind: secondary ? ButtonKind.outline : green ? ButtonKind.success : ButtonKind.primary,
      onTap: () => run(action),
    ),
  );
  Widget card(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: WCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  String money(dynamic paise) =>
      Fmt.rupees(((paise as num?) ?? 0).toInt() ~/ 100);
  String window(Map<String, dynamic> o) {
    final start = o['slotStart']?.toDate() as DateTime?,
        end = o['slotEnd']?.toDate() as DateTime?;
    return start == null
        ? 'Slot unavailable'
        : '${start.toLocal().toString().substring(0, 16)} – ${end?.toLocal().toString().substring(11, 16) ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final job = orders.where((o) => o['id'] == selected).firstOrNull;
    return WScreen(
      canvas: true,
      header: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            if (selected != null)
              IconButton(
                tooltip: 'Back to jobs',
                onPressed: () => setState(() {
                  selected = null;
                  sharing = false;
                }),
                icon: const Icon(Icons.arrow_back),
              ),
            const WText('wheelio.', WType.section),
            const Spacer(),
            const WBadge('Captain', icon: WIcon.user),
          ],
        ),
      ),
      footer: uid.isEmpty || selected != null
          ? null
          : WBottomNav(
              selection: tab,
              onSelect: (v) => setState(() => tab = v),
              items: const [
                NavItem(0, 'Jobs', WIcon.home),
                NavItem(1, 'Money', WIcon.rupee),
                NavItem(2, 'Account', WIcon.user),
              ],
            ),
      children: [
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: WBanner(tone: Tone.error, icon: WIcon.close, text: error),
          ),
        if (uid.isEmpty)
          ...login()
        else if (!loaded)
          const Center(child: CircularProgressIndicator())
        else if (captain.isEmpty) ...[
          const WTitleBlock('Finish your Captain account'),
          WTextField(
            label: 'Your name',
            value: name,
            onChanged: (v) => name = v,
          ),
          button(
            'Create Captain account',
            () => invoke('registerAccount', {'role': 'captain', 'name': name}),
          ),
        ] else if (job != null)
          ...jobDetails(job)
        else if (selected != null) ...[
          const WTitleBlock('Loading your job…'),
          button('Back to jobs', () async {
            setState(() => selected = null);
          }),
        ] else if (tab == 1)
          ...moneyTab()
        else if (tab == 2 || captain['approved'] != true)
          ...account()
        else
          ...jobs(),
      ],
    );
  }

  List<Widget> login() => [
    WTitleBlock(
      otpSent ? 'Enter the SMS code' : 'Earn with Wheelio',
      subtitle: otpSent
          ? 'Code sent to +91 $phone'
          : 'Doorstep exterior washes in Hyderabad societies.',
    ),
    if (!otpSent) ...[
      WTextField(label: 'Your name', value: name, onChanged: (v) => name = v),
      const Gap(16),
      WTextField(
        label: 'Mobile number',
        value: phone,
        keyboard: TextInputType.phone,
        onChanged: (v) => phone = v,
      ),
      const Gap(12),
      const WText(
        'By continuing, you agree to receive a verification SMS. Standard SMS rates may apply.',
        WType.caption,
      ),
      button('Get code', () async {
        if (name.trim().length < 2) throw ArgumentError('Enter your name.');
        await backend.requestOtp(phone);
        setState(() => otpSent = true);
      }),
    ] else ...[
      WTextField(
        label: '6-digit code',
        value: code,
        keyboard: TextInputType.number,
        onChanged: (v) => code = v,
      ),
      button('Verify and continue', () async {
        await backend.verifyOtp(code, role: 'captain', name: name);
        setState(() {
          otpSent = false;
          code = '';
        });
      }),
      button('Resend code', () => backend.requestOtp(phone), secondary: true),
      button('Change number', () async {
        backend.invalidateOtp();
        setState(() => otpSent = false);
      }, secondary: true),
    ],
  ];
  List<Widget> account() {
    final review = captain['kycStatus'] ?? 'notSubmitted';
    final editable = ['notSubmitted', 'changesRequested'].contains(review);
    return [
      WTitleBlock(
        'Hello, ${captain['name'] ?? name}',
        subtitle: captain['phone'] ?? '',
      ),
      WBadge(
        captain['approved'] == true
            ? 'Approved captain'
            : review == 'underReview'
            ? 'Application under review'
            : 'Complete your application',
        tone: captain['approved'] == true ? Tone.ok : Tone.wait,
        icon: WIcon.shield,
      ),
      const Gap(16),
      if (captain['reviewNote'] != null)
        WText(captain['reviewNote'], WType.body),
      if (editable) ...[
        const WText('Identity and payout details', WType.section),
        const WText(
          'Only the operations team can approve an application. Photos stay private.',
          WType.caption,
        ),
        for (final kind in ['aadhaar', 'selfie', 'bank'])
          button(
            '${uploaded.contains(kind) ? '✓ Replace' : 'Upload'} ${kind == 'aadhaar'
                ? 'identity proof'
                : kind == 'bank'
                ? 'bank proof'
                : 'selfie'}',
            () async {
              final bytes = await Device.pickImage();
              if (bytes == null) return;
              await backend.uploadKyc(kind, bytes);
              setState(() => uploaded.add(kind));
            },
            secondary: true,
          ),
        const Gap(16),
        WTextField(
          label: 'Payout UPI ID',
          value: upi,
          onChanged: (v) => setState(() => upi = v),
        ),
        const Gap(16),
        const WText('Choose your societies', WType.label),
        for (final s in config['societies'] as List? ?? [])
          if (s['active'] == true)
            CheckboxListTile(
              title: Text(s['name']),
              subtitle: Text(s['area']),
              value: selectedSocieties.contains(s['id']),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selectedSocieties.add(s['id']);
                      } else {
                        selectedSocieties.remove(s['id']);
                      }
                    }),
            ),
        button(
          'Submit for review',
          () => invoke('submitCaptainApplication', {
            'societyIds': selectedSocieties.toList(),
            'upi': upi,
          }),
          enabled: uploaded.length == 3 && selectedSocieties.isNotEmpty && RegExp(r'^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+$').hasMatch(upi.trim()),
        ),
      ] else if (captain['approved'] != true)
        const WText(
          'Your documents are saved. You can go online after the operations team reviews your application.',
          WType.body,
        ),
      if (captain['approved'] == true) ...[
        const Gap(16),
        WText(
          '${captain['completedWashes'] ?? 0} completed washes',
          WType.body,
        ),
        WText(
          'Rating: ${captain['ratingCount'] == 0 ? 'No ratings yet' : captain['rating']}',
          WType.body,
        ),
        WText(
          'Approved societies: ${(captain['societyIds'] as List? ?? []).map((id) => (config['societies'] as List? ?? []).where((s) => s['id'] == id).firstOrNull?['name'] ?? id).join(', ')}',
          WType.caption,
        ),
      ],
      button('Sign out', () async {
        if (captain['online'] == true) {
          await invoke('setCaptainOnline', {'online': false});
        }
        await backend.signOut();
      }, secondary: true),
    ];
  }

  List<Widget> jobs() => [
    const WTitleBlock(
      'Today’s plan',
      subtitle: 'Offers and accepted washes update automatically.',
    ),
    card([
      WBadge(
        captain['online'] == true ? 'Online' : 'Offline',
        tone: captain['online'] == true ? Tone.ok : Tone.mute,
        icon: WIcon.check,
      ),
      button(
        captain['online'] == true ? 'Go offline' : 'Go online',
        () => invoke('setCaptainOnline', {'online': captain['online'] != true}),
      ),
    ]),
    for (final o in offers)
      if (o['status'] == 'pending' &&
          (o['expiresAt']?.toDate() as DateTime?)?.isAfter(DateTime.now()) ==
              true &&
          captain['online'] == true)
        card([
          WText(
            'New ${o['vehicleName']} wash · ${money(o['captainPayPaise'])}',
            WType.section,
          ),
          WText('${o['societyName']} · ${o['area']}', WType.body),
          WText(window(o), WType.caption),
          WText(
            '${(o['expiresAt'].toDate() as DateTime).difference(DateTime.now()).inSeconds.clamp(0, 60)} seconds to accept',
            WType.caption,
          ),
          const WText(
            'Vehicle and parking details unlock after acceptance.',
            WType.caption,
          ),
          button('Accept job', () async {
            await invoke('claimJob', {'orderId': o['orderId']});
            setState(() => selected = o['orderId']);
          }, green: true),
          button(
            'Decline',
            () => invoke('rejectJob', {'orderId': o['orderId']}),
            secondary: true,
          ),
        ]),
    if (orders.isEmpty)
      const WText(
        'No accepted jobs yet. Go online to receive available offers in your approved societies.',
        WType.body,
      ),
    for (final o in orders)
      card([
        WText('${o['plate']} · ${money(o['captainPayPaise'])}', WType.title),
        WText(window(o), WType.caption),
        WText('${o['societyName']} · ${label(o['status'])}', WType.body),
        button('View wash', () async {
          setState(() => selected = o['id']);
        }, secondary: true),
      ]),
  ];
  List<Widget> moneyTab() => [
    const WTitleBlock(
      'Your earnings',
      subtitle:
          'Earnings stay pending until the customer approves the after photos.',
    ),
    if (earnings.isEmpty) const WText('No earnings yet.', WType.body),
    for (final e in earnings)
      card([
        WText(money(e['amount']), WType.section),
        WText(label(e['status']), WType.body),
        WText('Booking ${e['orderId']}', WType.caption),
      ]),
    const WBanner(
      tone: Tone.info,
      icon: WIcon.rupee,
      text:
          'Approved earnings are recorded here. Bank transfers require an operations payout; this screen does not mark money as sent.',
    ),
  ];
  List<Widget> jobDetails(Map<String, dynamic> o) {
    final status = o['status'], evidence = o['evidence'] as Map? ?? {};
    final after = status == 'washing', stage = after ? 'after' : 'before';
    return [
      WTitleBlock(
        o['plate'],
        subtitle: '${o['vehicleName']} · ${status == 'onTheWay' && o['arrivedAt'] != null ? 'Arrived' : label(status)}',
      ),
      card([
        WText('${o['societyName']}, ${o['area']}', WType.title),
        WText(
          '${o['tower']} · Floor ${o['floor']} · Parking ${o['parking']}',
          WType.body,
        ),
        WText(window(o), WType.caption),
        WText('Customer: ${o['customerFirstName']}', WType.body),
        WText(
          'Wash: ${o['washKind'] == 'dryDusting' ? 'Dry dusting' : 'Exterior wet wash'} · ${money(o['captainPayPaise'])}',
          WType.body,
        ),
      ]),
      if ((o['note'] ?? '').isNotEmpty)
        card([
          const WText('Owner’s note', WType.title),
          WText(o['note'], WType.body),
        ]),
      for (final path in (o['customerPhotos'] as Map? ?? {}).values)
        PrivatePhoto(path),
      if (['onTheWay', 'washing'].contains(status)) ...[
        button(
          sharing ? 'Stop sharing location' : 'Share live location',
          () async {
            if (!sharing) await backend.shareLocation(o['id']);
            setState(() => sharing = !sharing);
          },
          secondary: true,
        ),
        const Gap(8),
        const WText(
          'Location is shared only for this active wash while this page stays open.',
          WType.caption,
        ),
      ],
      if (status == 'onTheWay' && o['arrivedAt'] == null)
        button(
          'I’m at the vehicle',
          () => invoke('updateWashProgress', {
            'orderId': o['id'],
            'action': 'arrived',
          }),
        ),
      if ((status == 'onTheWay' && o['arrivedAt'] != null) ||
          status == 'washing') ...[
        WTitleBlock(
          after ? 'After photos' : 'Before photos',
          subtitle:
              'Take clear front, back, left and right photos of this vehicle.',
        ),
        for (var i = 0; i < 4; i++) ...[
          if (evidence['${stage}_$i'] != null)
            PrivatePhoto(evidence['${stage}_$i']['path'],key:ValueKey(evidence['${stage}_$i']['uploadedAt'].toString())),
          button(
            '${evidence['${stage}_$i'] != null ? '✓ Replace' : 'Add'} ${['front', 'back', 'left', 'right'][i]} photo',
            () async {
              final bytes = await Device.pickImage();
              if (bytes != null) {
                await backend.uploadEvidence(
                  orderId: o['id'],
                  after: after,
                  side: i,
                  bytes: bytes,
                );
              }
            },
            secondary: true,
          ),
        ],
        button(
          after ? 'Finish wash and send photos' : 'Start washing',
          () => invoke('updateWashProgress', {
            'orderId': o['id'],
            'action': after ? 'finish' : 'start',
          }),
          enabled: List.generate(
            4,
            (i) => evidence['${stage}_$i'],
          ).every((e) => e != null),
        ),
      ],
      if (status == 'photosReady')
        const WBanner(
          tone: Tone.wait,
          icon: WIcon.image,
          text: 'Photos sent. Waiting for customer approval.',
        ),
      if (status == 'approved')
        const WBanner(
          tone: Tone.ok,
          icon: WIcon.check,
          text:
              'Customer approved this wash. Your earnings ledger has been updated.',
        ),
      if (status == 'cancelled')
        const WBanner(
          tone: Tone.error,
          icon: WIcon.close,
          text: 'This booking was cancelled. Stop work on this vehicle.',
        ),
      if (status == 'disputed')
        const WBanner(
          tone: Tone.wait,
          icon: WIcon.shield,
          text:
              'The customer reported a problem. Earnings are on hold for operations review.',
        ),
    ];
  }

  String label(dynamic state) => switch (state) {
    'onTheWay' => 'On the way',
    'washing' => 'Washing',
    'photosReady' => 'Awaiting approval',
    'awaitingApproval' => 'Awaiting approval',
    'approved' => 'Approved',
    'onHold' => 'On hold',
    'cancelled' => 'Cancelled',
    'disputed' => 'Problem reported',
    _ => state.toString(),
  };
}
