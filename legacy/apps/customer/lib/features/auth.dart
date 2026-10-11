import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../config/app_config.dart';
import '../data/backend.dart';
import '../data/mock_backend.dart';
import '../data/models.dart';
import '../data/validators.dart';
import '../routes.dart';
import '../state/app_state.dart';
import 'common.dart';

void _finishLogin(BuildContext context) {
  final app = AppScope.read(context);
  final target = app.afterLogin ?? R.home;
  app.afterLogin = null;
  app.changed();
  context.go(target);
}

// ---------------------------------------------------------------------------
// C14-Login, C14b (invalid number)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.showError = false});

  final bool showError;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _phone;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.showError ? '98480 112' : AppScope.read(context).pendingPhone);
    if (widget.showError) _error = 'Enter all 10 digits';
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final digits = Validators.digitsOnly(_phone.text);
    if (!Validators.isValidMobile(digits)) {
      setState(() => _error = digits.length == 10 ? 'Enter a valid Indian mobile number' : 'Enter all 10 digits');
      return;
    }
    setState(() => _sending = true);
    final app = AppScope.read(context);
    final ok = await guarded(context, () async {
      await app.backend.requestOtp(digits);
      return true;
    });
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok == true) {
      app.pendingPhone = digits;
      context.push(R.otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WScreen(
      header: const SimpleHeader(fallback: R.review),
      children: [
        const WTitleBlock(title: 'Almost done. What’s your number?', subtitle: 'We’ll send a 6-digit code. No passwords.'),
        WTextField(
          label: 'Mobile number',
          controller: _phone,
          prefixText: '+91  ',
          error: _error,
          autofocus: true,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(12)],
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _send(),
        ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [WButton(label: 'Get code', loading: _sending, onPressed: _send)],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C15-Otp, C15b (wrong code), C15c (expired)

enum OtpView { entering, wrong, expired }

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, this.initial = OtpView.entering});

  final OtpView initial;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  late OtpView _view = widget.initial;
  int _triesLeft = 2;
  int _resendIn = AppConfig.otpResendSeconds;
  Timer? _timer;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial == OtpView.wrong) _code.text = '482190';
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _resendIn = AppConfig.otpResendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn = (_resendIn - 1).clamp(0, 999));
      if (_resendIn == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  String get _phone {
    final p = AppScope.read(context).pendingPhone;
    return p.isEmpty ? '9848011223' : p;
  }

  Future<void> _resend() async {
    final app = AppScope.read(context);
    await guarded(context, () => app.backend.requestOtp(_phone));
    if (!mounted) return;
    _code.clear();
    setState(() => _view = OtpView.entering);
    _startTimer();
    showWSnack(context, 'New code sent to ${formatPhone(_phone)}');
  }

  Future<void> _verify() async {
    if (_code.text.length < AppConfig.otpLength || _verifying) return;
    setState(() => _verifying = true);
    final app = AppScope.read(context);
    final result = await guarded(context, () => app.backend.verifyOtp(_phone, _code.text));
    if (!mounted || result == null) {
      if (mounted) setState(() => _verifying = false);
      return;
    }
    setState(() => _verifying = false);
    switch (result.status) {
      case OtpStatus.ok:
        app.changed();
        if (result.isNewCustomer) {
          context.pushReplacement(R.name);
        } else {
          _finishLogin(context);
        }
      case OtpStatus.wrong:
        setState(() {
          _view = OtpView.wrong;
          _triesLeft = result.triesLeft;
        });
      case OtpStatus.expired:
      case OtpStatus.tooManyTries:
        _code.clear();
        setState(() => _view = OtpView.expired);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = switch (_view) {
      OtpView.entering => null,
      OtpView.wrong => 'That code doesn’t match. $_triesLeft ${_triesLeft == 1 ? 'try' : 'tries'} left.',
      OtpView.expired => 'That code expired. Get a new one.',
    };
    return WScreen(
      header: const SimpleHeader(fallback: R.login),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text('Enter the code', style: WText.screen)),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Sent to ${formatPhone(_phone)}. ', style: WText.body),
                WLinkButton(label: 'Change', onTap: () => goBack(context, R.login)),
              ],
            ),
          ],
        ),
        if (_view != OtpView.expired)
          WOtpField(
            controller: _code,
            length: AppConfig.otpLength,
            error: _view == OtpView.wrong,
            onCompleted: (_) => _verify(),
          ),
        if (message != null)
          WBanner(
            tone: WTone.error,
            text: message,
            action: _view == OtpView.expired ? WLinkButton(label: 'Resend', onTap: _resend) : null,
          ),
        if (_view == OtpView.expired)
          Align(
            alignment: Alignment.centerLeft,
            child: WLinkButton(
              label: 'Get the code on a call instead',
              onTap: () => showWSnack(context, 'We’ll call ${formatPhone(_phone)} with the code'),
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: _resendIn > 0
                ? Text('Resend code in ${formatClock(_resendIn)}', style: WText.caption)
                : WLinkButton(label: 'Resend code', onTap: _resend),
          ),
        if (AppConfig.useMock)
          WBanner(
            tone: WTone.mute,
            icon: Icons.science_outlined,
            text: 'Demo mode: use code ${MockBackend.demoOtp}. ${MockBackend.expiredOtp} shows the expired state.',
          ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          ListenableBuilder(
            listenable: _code,
            builder: (context, _) => WButton(
              label: 'Verify',
              loading: _verifying,
              onPressed: _view == OtpView.expired || _code.text.length < AppConfig.otpLength ? null : _verify,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C16-Name

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  late final TextEditingController _name = TextEditingController(text: AppScope.read(context).customer?.name ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!Validators.isValidName(_name.text)) return;
    setState(() => _saving = true);
    final app = AppScope.read(context);
    final c = await guarded(context, () => app.backend.updateName(_name.text));
    if (!mounted) return;
    setState(() => _saving = false);
    if (c != null) _finishLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return WScreen(
      header: const SimpleHeader(fallback: R.home),
      children: [
        const WTitleBlock(title: 'What should we call you?', subtitle: 'Your washer sees your first name only.'),
        WTextField(
          label: 'Your name',
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          onSubmitted: (_) => _save(),
        ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          ListenableBuilder(
            listenable: _name,
            builder: (context, _) => WButton(
              label: 'Continue',
              loading: _saving,
              onPressed: Validators.isValidName(_name.text) ? _save : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C54-SessionExpired

class SessionExpiredScreen extends StatelessWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) => WScreen(
        body: const WStateView(
          icon: Icons.lock_clock_outlined,
          tone: WTone.info,
          title: 'Please log in again',
          body: 'For your safety we log you out after ${AppConfig.sessionDays} days. Your bookings are safe.',
        ),
        footer: WFooterBar(children: [
          WButton(
            label: 'Log in',
            onPressed: () {
              AppScope.read(context).afterLogin = R.home;
              context.go(R.login);
            },
          ),
        ]),
      );
}
