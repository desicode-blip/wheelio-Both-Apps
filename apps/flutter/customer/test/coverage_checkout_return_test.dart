import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/store.dart';
void main(){
 testWidgets('late checkout login returns to Review even after a manual address', (tester)async{
  await tester.pumpWidget(const SizedBox());final r=AppRouter();
  r.go(N.manualAddress);r.go(N.review);r.go(N.login);r.go(N.otp);
  r.finishLogin();expect(r.last?.n,N.review);expect(r.showPaySheet,false);
  await tester.pump(const Duration(milliseconds:450));expect(r.showPaySheet,true);r.dispose();
 });
 test('login requested by a legacy address check returns to that address form',(){
  final r=AppRouter();r.go(N.manualAddress);r.go(N.login);r.go(N.otp);r.finishLogin();
  expect(r.last?.n,N.manualAddress);expect(r.showPaySheet,false);r.dispose();
 });
}
