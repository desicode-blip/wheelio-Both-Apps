import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import 'backend.dart';
import 'live_backend.dart';

/// The designed sample-data apps are available only with an explicit demo URL.
Future<void> launchWashKrew({
  required bool captain,
  required Widget demo,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  WashKrewRuntime.backend = null;
  // Web: ?demo=true. Phone builds: --dart-define=WHEELIO_DEMO=true (sample data, no Firebase).
  if (Uri.base.queryParameters['demo'] == 'true' ||
      const bool.fromEnvironment('WHEELIO_DEMO')) {
    runApp(demo);
    return;
  }
  Object? initializationError;
  try {
    await WashKrewFirebase.initialize(captain: captain);
    WashKrewRuntime.backend = LiveBackend();
  } catch (error) {
    initializationError = error;
  }
  runApp(
    initializationError == null
        ? demo
        : _PortalApp(captain: captain, configured: false),
  );
}

/// Label every explicit sample-data build, including installed phone builds.
class DemoLabel extends StatelessWidget {
  const DemoLabel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => !WashKrewRuntime.demo
      ? child
      : Column(
          children: [
            const Material(
              color: Color(0xFFFFE6A8),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: Center(
                    child: Text(
                      'DEMO · Sample data · No bookings or payments',
                      style: TextStyle(
                        color: WColor.heading,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
}

class _PortalApp extends StatelessWidget {
  const _PortalApp({required this.captain, required this.configured});
  final bool captain;
  final bool configured;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: captain ? Brand.captainApp : Brand.name,
    theme: ThemeData(
      fontFamily: wFont,
      useMaterial3: true,
      scaffoldBackgroundColor: WColor.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: WColor.primary,
        primary: WColor.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    builder: (context, child) => PhoneFrame(child: child!),
    home: configured ? _Session(captain: captain) : const _Unavailable(),
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BrandLogo(),
            SizedBox(height: 32),
            Text(
              'We’re getting ready',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'The live app is not configured yet. Please come back soon.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Session extends StatelessWidget {
  const _Session({required this.captain});
  final bool captain;
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snapshot.data == null) return _AuthPage(captain: captain);
      return _ProfileLoader(
        key: ValueKey(snapshot.data!.uid),
        captain: captain,
      );
    },
  );
}

class _ProfileLoader extends StatefulWidget {
  const _ProfileLoader({super.key, required this.captain});
  final bool captain;
  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  late Future<void> ready = WashKrewRepository().ensureProfile();
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(backendError(snapshot.error!)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(
                      () => ready = WashKrewRepository().ensureProfile(),
                    ),
                    child: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Log out'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return _Dashboard(captain: widget.captain);
    },
  );
}

class _AuthPage extends StatefulWidget {
  const _AuthPage({required this.captain});
  final bool captain;
  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController();
  bool register = true, busy = false, sms = false;
  String? error, info;
  ConfirmationResult? confirmation;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = backendError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _submit() async {
    if (!form.currentState!.validate()) return;
    await _run(() async {
      final auth = FirebaseAuth.instance;
      if (sms) {
        if (confirmation == null) {
          final result = await auth.signInWithPhoneNumber(
            '+91${phone.text.trim()}',
          );
          if (mounted)
            setState(() {
              confirmation = result;
              info = 'A code was sent to your phone.';
            });
        } else {
          await confirmation!.confirm(code.text.trim());
        }
      } else if (register) {
        await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: _BrandLogo()),
          const SizedBox(height: 36),
          Text(
            widget.captain
                ? 'Your next chapter\nstarts nearby.'
                : 'A clean car.\nA little more weekend.',
            style: const TextStyle(
              fontSize: 32,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: WColor.heading,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.captain
                ? 'Join the ${Brand.captainApp} list in Hyderabad.'
                : 'Join ${Brand.name} and book a wash in your society.',
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: WColor.secondary,
            ),
          ),
          const SizedBox(height: 20),
          const _Notice(
            'Prelaunch · Requests are saved to your account. Service, pricing and payments are not live yet.',
          ),
          const SizedBox(height: 24),
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sms
                      ? 'Sign in with your phone'
                      : register
                      ? 'Create your account'
                      : 'Welcome back',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                if (sms) ...[
                  TextFormField(
                    controller: phone,
                    enabled: confirmation == null && !busy,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixText: '+91 ',
                    ),
                    keyboardType: TextInputType.phone,
                    autofillHints: const [
                      AutofillHints.telephoneNumberNational,
                    ],
                    validator: (v) =>
                        RegExp(r'^[6-9]\d{9}$').hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Enter a valid 10-digit Indian mobile number.',
                  ),
                  if (confirmation != null) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: code,
                      decoration: const InputDecoration(labelText: 'SMS code'),
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                          ? null
                          : 'Enter the 6-digit code.',
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              confirmation = null;
                              code.clear();
                            }),
                      child: const Text('Change number or resend'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'By continuing, you agree to receive a verification SMS. Standard message rates may apply.',
                    style: TextStyle(fontSize: 12, color: WColor.secondary),
                  ),
                ] else ...[
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) =>
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Enter a valid email address.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    autofillHints: [
                      register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    validator: (v) => (v?.length ?? 0) >= (register ? 8 : 1)
                        ? null
                        : 'Use at least 8 characters.',
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      error!,
                      style: const TextStyle(color: WColor.destructive),
                    ),
                  ),
                if (info != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(info!),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          sms
                              ? confirmation == null
                                    ? 'Send code'
                                    : 'Verify code'
                              : register
                              ? 'Create account'
                              : 'Log in',
                        ),
                ),
                if (!sms)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            register = !register;
                            error = null;
                            info = null;
                          }),
                    child: Text(
                      register
                          ? 'Already have an account? Log in'
                          : 'New to ${Brand.name}? Create an account',
                    ),
                  ),
                if (!sms && !register)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _run(() async {
                            if (!RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(email.text.trim())) {
                              setState(
                                () => error = 'Enter your email address first.',
                              );
                              return;
                            }
                            await FirebaseAuth.instance.sendPasswordResetEmail(
                              email: email.text.trim(),
                            );
                            if (mounted)
                              setState(
                                () => info =
                                    'If this email has an account, a reset link will arrive shortly.',
                              );
                          }),
                    child: const Text('Forgot password?'),
                  ),
                if (kIsWeb &&
                    const bool.fromEnvironment('FIREBASE_PHONE_AUTH_ENABLED'))
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            sms = !sms;
                            error = null;
                            info = null;
                            confirmation = null;
                            code.clear();
                          }),
                    child: Text(
                      sms ? 'Use email instead' : 'Use a phone number instead',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();
  @override
  Widget build(BuildContext context) => const WLogo(kind: WLogoKind.lockup, height: 72);
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: WColor.primaryTint,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 20, color: WColor.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(height: 1.5, color: WColor.heading),
          ),
        ),
      ],
    ),
  );
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({required this.captain});
  final bool captain;
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.captain ? Brand.captainApp : Brand.name),
      backgroundColor: WColor.canvas,
    ),
    body: switch (tab) {
      1 => widget.captain ? const _AccountPage() : const _RequestsPage(),
      2 => const _AccountPage(),
      _ =>
        widget.captain
            ? const _CaptainApplication()
            : _RequestPage(onSubmitted: () => setState(() => tab = 1)),
    },
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: [
        NavigationDestination(
          icon: Icon(
            widget.captain
                ? Icons.badge_outlined
                : Icons.local_car_wash_outlined,
          ),
          label: widget.captain ? 'Join as captain' : 'Request a wash',
        ),
        if (!widget.captain)
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'My requests',
          ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    ),
  );
}

class _RequestPage extends StatefulWidget {
  const _RequestPage({required this.onSubmitted});
  final VoidCallback onSubmitted;
  @override
  State<_RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<_RequestPage> {
  final form = GlobalKey<FormState>();
  final registration = TextEditingController(),
      society = TextEditingController(),
      parking = TextEditingController(),
      notes = TextEditingController();
  String vehicle = 'hatchback', wash = 'wetOutside', window = '8–10 AM';
  DateTime date = DateTime.now().add(const Duration(days: 1));
  bool busy = false;
  String? error;
  @override
  void dispose() {
    registration.dispose();
    society.dispose();
    parking.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await WashKrewRepository().requestWash({
        'vehicleType': vehicle,
        'registration': registration.text.trim().toUpperCase().replaceAll(
          ' ',
          '',
        ),
        'society': society.text.trim(),
        'parking': parking.text.trim(),
        'notes': notes.text.trim(),
        'washType': wash,
        'preferredDate': _date(date),
        'timeWindow': window,
      });
      if (!mounted) return;
      registration.clear();
      parking.clear();
      notes.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request saved. No payment has been taken.'),
        ),
      );
      widget.onSubmitted();
    } catch (e) {
      if (mounted) setState(() => error = backendError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Less washing.\nMore living.',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: WColor.heading,
        ),
      ),
      const SizedBox(height: 12),
      const _Notice(
        'Tell us what you need. This is a service request, not a confirmed booking. We are preparing to launch in Hyderabad. No payment is taken.',
      ),
      const SizedBox(height: 24),
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: vehicle,
              decoration: const InputDecoration(labelText: 'Vehicle'),
              items: const [
                DropdownMenuItem(value: 'bike', child: Text('Bike or scooter')),
                DropdownMenuItem(value: 'hatchback', child: Text('Hatchback')),
                DropdownMenuItem(value: 'sedan', child: Text('Sedan')),
                DropdownMenuItem(value: 'suv', child: Text('SUV or MUV')),
              ],
              onChanged: (v) => setState(() => vehicle = v!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: registration,
              decoration: const InputDecoration(
                labelText: 'Vehicle number',
                hintText: 'TS 09 AB 1234',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 15,
              validator: (v) =>
                  RegExp(
                    r'^[A-Z0-9]{6,12}$',
                  ).hasMatch((v ?? '').toUpperCase().replaceAll(' ', ''))
                  ? null
                  : 'Enter your vehicle registration.',
            ),
            TextFormField(
              controller: society,
              decoration: const InputDecoration(
                labelText: 'Society in Hyderabad',
              ),
              maxLength: 120,
              validator: _required,
            ),
            TextFormField(
              controller: parking,
              decoration: const InputDecoration(
                labelText: 'Tower, floor and parking slot',
              ),
              maxLength: 120,
              validator: _required,
            ),
            DropdownButtonFormField<String>(
              initialValue: wash,
              decoration: const InputDecoration(labelText: 'Wash type'),
              items: const [
                DropdownMenuItem(
                  value: 'dryDusting',
                  child: Text('Dry dusting'),
                ),
                DropdownMenuItem(
                  value: 'wetOutside',
                  child: Text('Wet exterior wash'),
                ),
              ],
              onChanged: (v) => setState(() => wash = v!),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Preferred date · ${_date(date)}'),
              onPressed: () async {
                final now = DateTime.now();
                final chosen = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: now.add(const Duration(days: 60)),
                );
                if (chosen != null && mounted) setState(() => date = chosen);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: window,
              decoration: const InputDecoration(labelText: 'Preferred time'),
              items: [
                '6–8 AM',
                '8–10 AM',
                '10 AM–12 PM',
                '12–2 PM',
                '2–4 PM',
                '4–6 PM',
              ].map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
              onChanged: (v) => setState(() => window = v!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: notes,
              decoration: const InputDecoration(
                labelText: 'Access notes (optional)',
              ),
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  error!,
                  style: const TextStyle(color: WColor.destructive),
                ),
              ),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(busy ? 'Saving…' : 'Send wash request'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pricing and availability will be confirmed separately when service opens.',
              style: TextStyle(fontSize: 12, color: WColor.secondary),
            ),
          ],
        ),
      ),
    ],
  );
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String? _required(String? value) =>
    (value?.trim().length ?? 0) >= 2 ? null : 'Please fill in this field.';

class _RequestsPage extends StatelessWidget {
  const _RequestsPage();
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: WashKrewRepository().requests.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(backendError(snapshot.error!)),
          ),
        );
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data!.docs;
      if (docs.isEmpty)
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_car_wash_outlined,
                  size: 56,
                  color: WColor.primary,
                ),
                SizedBox(height: 16),
                Text(
                  'Your requests will appear here',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Send your first wash request from the home tab.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'My requests',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Updates appear here automatically. These are not confirmed bookings.',
          ),
          const SizedBox(height: 20),
          for (final doc in docs) _RequestCard(id: doc.id, data: doc.data()),
        ],
      );
    },
  );
}

class _RequestCard extends StatefulWidget {
  const _RequestCard({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;
  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_car_outlined,
                  color: WColor.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    d['registration'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(d['society'] as String? ?? ''),
            Text(d['parking'] as String? ?? ''),
            const SizedBox(height: 10),
            Text('${d['preferredDate']} · ${d['timeWindow']}'),
            const SizedBox(height: 10),
            Chip(
              avatar: Icon(
                d['status'] == 'cancelled'
                    ? Icons.cancel_outlined
                    : Icons.schedule,
                size: 16,
              ),
              label: Text(
                d['status'] == 'cancelled' ? 'Cancelled' : 'Request received',
              ),
            ),
            Text(
              'Reference: ${widget.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: WColor.secondary),
            ),
            if (d['status'] == 'requested')
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Cancel this request?'),
                            content: const Text(
                              'No payment was taken, so there is no cancellation fee.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Keep request'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Cancel request'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !mounted) return;
                        setState(() => busy = true);
                        try {
                          await WashKrewRepository().cancelRequest(widget.id);
                        } catch (e) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(backendError(e))),
                            );
                        }
                        if (mounted) setState(() => busy = false);
                      },
                child: Text(busy ? 'Cancelling…' : 'Cancel request'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaptainApplication extends StatefulWidget {
  const _CaptainApplication();
  @override
  State<_CaptainApplication> createState() => _CaptainApplicationState();
}

class _CaptainApplicationState extends State<_CaptainApplication> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      area = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    area.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: WashKrewRepository().application.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Center(child: Text(backendError(snapshot.error!)));
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final data = snapshot.data!.data();
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Work close to home.',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _Notice(
            data == null
                ? 'Register your interest in joining ${Brand.name}. We’ll review applications before service starts. No jobs or payouts are live yet.'
                : 'Application received. Your details are saved. Onboarding and identity verification will open before you can accept jobs.',
          ),
          const SizedBox(height: 24),
          if (data != null) ...[
            const Icon(
              Icons.check_circle_outline,
              color: WColor.primary,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              data['name'] as String? ?? '',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(data['phone'] as String? ?? ''),
            Text(data['area'] as String? ?? ''),
            const SizedBox(height: 18),
            const Chip(
              avatar: Icon(Icons.schedule, size: 18),
              label: Text('Awaiting onboarding'),
            ),
          ] else
            Form(
              key: form,
              child: Column(
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    validator: _required,
                  ),
                  TextFormField(
                    controller: phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixText: '+91 ',
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '')
                        ? null
                        : 'Enter a valid 10-digit mobile number.',
                  ),
                  TextFormField(
                    controller: area,
                    decoration: const InputDecoration(
                      labelText: 'Preferred work area in Hyderabad',
                    ),
                    maxLength: 120,
                    validator: _required,
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: WColor.destructive),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              await WashKrewRepository().applyAsCaptain(
                                name: name.text,
                                phone: phone.text,
                                area: area.text,
                              );
                            } catch (e) {
                              if (mounted)
                                setState(() => error = backendError(e));
                            }
                            if (mounted) setState(() => busy = false);
                          },
                    child: Text(busy ? 'Saving…' : 'Join the captain list'),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _AccountPage extends StatefulWidget {
  const _AccountPage();
  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  final name = TextEditingController();
  bool loaded = false, busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: WashKrewRepository().profile.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Center(child: Text(backendError(snapshot.error!)));
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      if (!loaded) {
        name.text = snapshot.data!.data()?['name'] as String? ?? '';
        loaded = true;
      }
      final user = FirebaseAuth.instance.currentUser!;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Your account',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(user.email ?? user.phoneNumber ?? ''),
          const SizedBox(height: 20),
          TextField(
            controller: name,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Your name'),
            textCapitalization: TextCapitalization.words,
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: WColor.destructive)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (name.text.trim().length < 2) {
                      setState(() => error = 'Enter your name.');
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await WashKrewRepository().saveProfile(name.text);
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name saved.')),
                        );
                    } catch (e) {
                      if (mounted) setState(() => error = backendError(e));
                    }
                    if (mounted) setState(() => busy = false);
                  },
            child: Text(busy ? 'Saving…' : 'Save name'),
          ),
          const SizedBox(height: 24),
          const _Notice(
            '${Brand.name} is preparing to launch. Your requests and application are private to your account. Payments, captain matching and live wash tracking are not active yet.',
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } catch (e) {
                if (mounted) setState(() => error = backendError(e));
              }
            },
            child: const Text('Log out'),
          ),
        ],
      );
    },
  );
}
