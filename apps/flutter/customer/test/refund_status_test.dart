import 'package:flutter_test/flutter_test.dart';
import 'package:wheelio_customer/data/refund_status.dart';

void main() {
  test('a rejected refund is delayed and remains due rather than appearing sent', () {
    final copy = refundStatusText('delayed', 'providerRejected');
    expect(copy.title, 'Refund delayed');
    expect(copy.detail, contains('remains due'));
    expect(copy.detail, contains('retry automatically'));
  });
  test('a failed provider refund requests review without claiming automatic success', () {
    final copy = refundStatusText('delayed', 'providerFailed');
    expect(copy.title, 'Refund needs review');
    expect(copy.detail, contains('operations review'));
    expect(copy.detail, isNot(contains('retry automatically')));
  });
  test('only server-confirmed states say sent or processed', () {
    expect(refundStatusText(null, null).title, 'Refund queued');
    expect(refundStatusText('submitted', null).title, 'Refund sent to Razorpay');
    expect(refundStatusText('processed', null).title, 'Refund processed');
  });
}
