Future<void> preloadCheckout() async {}

Future<Map<String, dynamic>?> openCheckout(
  Map<String, dynamic> options,
  String phone, {Future<bool> Function()? onReturn, void Function()? onReturned}
) => throw UnsupportedError(
  'Razorpay checkout is currently available in the web app.',
);
