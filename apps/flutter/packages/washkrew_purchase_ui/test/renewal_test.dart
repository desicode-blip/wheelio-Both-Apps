import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';

void main() {
  test('Monthly renewal defaults on without assuming mandate approval', () {
    final s = PurchaseSelection()..mode = PurchaseMode.monthly;
    expect(s.autoRenew, isTrue);
    expect(s.renewalAuthorityGranted, isFalse);
    expect(s.renewalMethod, RenewalMethod.upiAutopay);
  });
  test(
    'Plan snapshot keeps authorization and cancellation cannot remove paid visits',
    () {
      final s = PurchaseSelection()
        ..mode = PurchaseMode.monthly
        ..confirmed = true
        ..renewalAuthorityGranted = true;
      final copy = s.snapshot();
      final visits = copy.visits.toList();
      copy.update(() {
        copy.autoRenew = false;
        copy.renewalAuthorityGranted = false;
      });
      expect(copy.visits, visits);
      expect(copy.confirmed, isTrue);
      expect(s.autoRenew, isTrue);
      expect(s.renewalAuthorityGranted, isTrue);
    },
  );
}
