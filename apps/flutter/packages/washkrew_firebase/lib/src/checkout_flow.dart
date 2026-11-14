/// Real network/SDK stages, displayed in the existing payment state layout.
enum CheckoutStage { preparing, savingAttachments, opening, confirming }

typedef CheckoutCall =
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>);
typedef CheckoutUpload = Future<void> Function(String bookingId);
typedef CheckoutOpen =
    Future<Map<String, dynamic>?> Function(Map<String, dynamic>, String);

class CheckoutFlow {
  CheckoutFlow({required this.call, required this.open, required this.phone});
  final CheckoutCall call;
  final CheckoutOpen open;
  final String phone;

  Future<Map<String, dynamic>> run({
    String? bookingId,
    Map<String, dynamic>? booking,
    List<CheckoutUpload> uploads = const [],
    void Function(String)? onBookingReady,
    void Function(CheckoutStage)? onStage,
  }) async {
    if ((bookingId == null) == (booking == null)) {
      throw ArgumentError('Provide a booking or an existing booking ID.');
    }
    onStage?.call(CheckoutStage.preparing);
    var pendingUploads = uploads;
    var deferPreparation = uploads.isNotEmpty;
    // Attachments remain locked before payment. Upload in parallel with provider
    // preparation, and never open the SDK until all selected evidence is saved.
    if (uploads.isNotEmpty && bookingId == null) {
      final created = await call('createBooking', booking!);
      bookingId = created['bookingId'] as String;
      onBookingReady?.call(bookingId);
      // A zero-cash checkout settles wallet/free-wash payment immediately. It
      // must wait for evidence; preparing a paid Razorpay order does not settle.
      deferPreparation =
          created['amount'] is! int || (created['amount'] as int) <= 0;
      // Retrying a callback after capture must not try to rewrite locked photos.
      if (created['status'] != 'pendingPayment') pendingUploads = const [];
    }
    final existingId = bookingId;
    Future<Map<String, dynamic>> prepare() => call('createCheckout', {
      if (existingId != null) 'bookingId': existingId else 'booking': booking,
    });
    late final Map<String, dynamic> options;
    if (pendingUploads.isNotEmpty) {
      onStage?.call(CheckoutStage.savingAttachments);
      if (deferPreparation) {
        await Future.wait([
          for (final upload in pendingUploads)
            Future<void>.sync(() => upload(existingId!)),
        ]);
        options = await prepare();
      } else {
        final results = await Future.wait<Object?>([
          prepare(),
          for (final upload in pendingUploads)
            Future<void>.sync(() => upload(existingId!)),
        ]);
        options = results.first! as Map<String, dynamic>;
      }
    } else {
      options = await prepare();
    }
    final id = options['bookingId'];
    if (id is! String ||
        id.isEmpty ||
        (existingId != null && id != existingId)) {
      throw StateError('Reopen this booking to prepare payment again.');
    }
    // 14 Nov: a team test booking is never sent to Razorpay. A server without test
    // bookings (not deployed yet) returns a normal payment order; stop before it opens.
    if (booking?['testBooking'] == true && options['paid'] != true) {
      throw const TestBookingUnavailable();
    }
    onBookingReady?.call(id);
    if (options['paid'] == true) {
      onStage?.call(CheckoutStage.confirming);
      return call('checkPayment', {'bookingId': id});
    }
    onStage?.call(CheckoutStage.opening);
    Map<String, dynamic>? result;
    try {
      result = await open(options, phone);
    } catch (_) {
      // The native callback can be lost after a UPI app switch. Only the server
      // can establish capture; retain reconciliation before allowing a retry.
      onStage?.call(CheckoutStage.confirming);
      try {
        final checked = await call('checkPayment', {'bookingId': id});
        if (checked['paymentStatus'] == 'captured') return checked;
      } catch (_) {
        /* Keep the original SDK error and recoverable booking. */
      }
      rethrow;
    }
    onStage?.call(CheckoutStage.confirming);
    if(result?['_serverConfirmed']==true)return call('checkPayment', {'bookingId':id});
    if (result == null) {
      final checked = await call('checkPayment', {'bookingId': id});
      if (checked['paymentStatus'] == 'captured') return checked;
      return call('abandonCheckout', {'bookingId': id});
    }
    return call('verifyPayment', {
      'bookingId': id,
      'orderId': result['razorpay_order_id'],
      'paymentId': result['razorpay_payment_id'],
      'signature': result['razorpay_signature'],
    });
  }
}

/// The server can't take team test bookings yet (it would ask for a real payment).
class TestBookingUnavailable implements Exception {
  const TestBookingUnavailable();
  @override
  String toString() => 'Test bookings need the updated server.';
}
