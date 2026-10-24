import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'checkout_options.dart';

bool _open = false;

Future<Map<String, dynamic>?> openCheckout(
  Map<String, dynamic> options,
  String phone,
) async {
  if (defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.android) {
    throw StateError('Open Wheelio on your phone or in the web app to pay.');
  }
  if (_open)
    throw StateError(
      'A payment is already open. Return to that checkout first.',
    );
  final settings = checkoutOptions(options, phone);
  _open = true;
  final razorpay = Razorpay();
  final result = Completer<Map<String, dynamic>?>();
  try {
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
      PaymentSuccessResponse response,
    ) {
      if (result.isCompleted) return;
      if (response.orderId != options['orderId'] ||
          (response.paymentId ?? '').isEmpty ||
          (response.signature ?? '').isEmpty) {
        result.completeError(
          StateError(
            'Payment confirmation is incomplete. Check this booking’s payment status before retrying.',
          ),
        );
        return;
      }
      result.complete({
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
      });
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (
      PaymentFailureResponse response,
    ) {
      if (result.isCompleted) return;
      if (response.code == Razorpay.PAYMENT_CANCELLED) {
        result.complete(null);
      } else {
        // Never show raw SDK/provider payloads, which may include private data.
        result.completeError(
          StateError(
            'Payment did not complete. Reopen this booking to check or retry payment.',
          ),
        );
      }
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (
      ExternalWalletResponse response,
    ) {
      // Selecting a wallet is not proof of capture; the backend checks status.
      if (!result.isCompleted) result.complete(null);
    });
    razorpay.open(settings);
    return await result.future.timeout(
      const Duration(minutes: 20),
      onTimeout: () => throw StateError(
        'Payment confirmation is still pending. Check this booking’s payment status.',
      ),
    );
  } finally {
    razorpay.clear();
    _open = false;
  }
}
