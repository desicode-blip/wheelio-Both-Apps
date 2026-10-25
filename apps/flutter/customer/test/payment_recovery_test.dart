import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';

void main() {
  test('unpaid and unconfirmed bookings stay visible for checkout recovery', () {
    expect(OrderStatus.pendingPayment.isUpcoming, isTrue);
    expect(OrderStatus.paymentPending.isUpcoming, isTrue);
    expect(OrderStatus.pendingPayment.isActive, isFalse);
    expect(OrderStatus.approved.isUpcoming, isFalse);
    expect(OrderStatus.cancelled.isUpcoming, isFalse);
  });
}
