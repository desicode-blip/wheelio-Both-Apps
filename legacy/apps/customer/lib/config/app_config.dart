/// App-wide configuration. Values that are not decided yet are kept here as
/// config so a decision touches one line (design read-me: "Placeholders").
///
/// Secrets are never committed. Pass them at build time:
///   flutter run --dart-define-from-file=env/dev.json
abstract final class AppConfig {
  /// data-token="brand/name". "Wheelio" is a working name.
  static const brandName = String.fromEnvironment('BRAND_NAME', defaultValue: 'Wheelio');
  static const tagline = 'Clean wheels, zero hassle';

  /// "mock" runs the whole app on sample data with no network.
  /// "supabase" uses the real backend once it is connected.
  static const backend = String.fromEnvironment('BACKEND', defaultValue: 'mock');
  static bool get useMock => backend != 'supabase';

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');
  static const googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_KEY');

  // Support (placeholders until the real numbers exist).
  static const supportPhone = String.fromEnvironment('SUPPORT_PHONE', defaultValue: '+910000000000');
  static const supportWhatsApp = String.fromEnvironment('SUPPORT_WHATSAPP', defaultValue: '+910000000000');
  static const supportHours = '7 AM – 9 PM, every day. Calls in English, Hindi or Telugu.';
  static const termsUrl = 'https://example.com/terms';
  static const privacyUrl = 'https://example.com/privacy';

  // Business rules. Proposed in the roadmap; "Open decisions" still to sign off.
  /// Silence means auto-approval after this window (roadmap F14).
  static const approvalWindow = Duration(hours: 2);

  /// Dispute window after approval (roadmap F16).
  static const disputeWindow = Duration(hours: 24);

  /// Not decided: [CANCELLATION FEE], [REFUND AMOUNT], [WAIT FEE].
  /// While null the UI shows the placeholder text from the designs.
  static const int? cancellationFeeRupees = null;
  static const int? waitFeeRupees = null;

  static const otpLength = 6;
  static const otpResendSeconds = 30;
  static const otpMaxTries = 3;
  static const sessionDays = 30;
  static const walkaroundVideoSeconds = 15;
}
