/// Customer copy comes from verified server states, never raw provider errors.
({String title, String detail}) refundStatusText(String? status, String? issue) {
  if (status == 'processed') {
    return (title: 'Refund processed', detail: 'Razorpay confirmed the refund to your original payment method. Bank processing time may vary.');
  }
  if (status == 'submitted') {
    return (title: 'Refund sent to Razorpay', detail: 'Razorpay accepted the refund. Bank processing time may vary.');
  }
  if (status == 'delayed' || status == 'retry' || status == 'needsReview') {
    final review = status == 'needsReview' || issue == 'providerFailed' || issue == 'verificationFailed';
    return (
      title: review ? 'Refund needs review' : 'Refund delayed',
      detail: review
          ? 'The refund needs an operations review. The amount shown remains due.'
          : 'The payment provider has not accepted the refund yet. The amount shown remains due, and we will retry automatically.',
    );
  }
  return (title: 'Refund queued', detail: 'Your refund is waiting to be sent to Razorpay. It will return to the original payment method.');
}
