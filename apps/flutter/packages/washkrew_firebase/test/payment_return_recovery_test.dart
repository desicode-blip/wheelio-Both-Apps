import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/src/payment_return_recovery.dart';
void main(){
 testWidgets('UPI return without SDK callback requires actual server capture and stops on dispose',(tester)async{
  var checks=0,accepted=0;final recovery=PaymentReturnRecovery(check:()async=>++checks>=2,onCaptured:()=>accepted++);
  recovery.didChangeAppLifecycleState(AppLifecycleState.resumed);await tester.pump(const Duration(seconds:1));expect(checks,0);
  recovery.didChangeAppLifecycleState(AppLifecycleState.paused);recovery.didChangeAppLifecycleState(AppLifecycleState.resumed);
  await tester.pump(const Duration(milliseconds:500));await tester.pump();expect(checks,1);expect(accepted,0);
  await tester.pump(const Duration(seconds:2));await tester.pump();expect(accepted,1);
  recovery.dispose();await tester.pump(const Duration(seconds:5));expect(checks,2);
 });
 testWidgets('late server response after closing checkout cannot navigate or complete a new payment',(tester)async{
  final check=Completer<bool>();var accepted=0;
  final recovery=PaymentReturnRecovery(check:()=>check.future,onCaptured:()=>accepted++);
  recovery.didChangeAppLifecycleState(AppLifecycleState.paused);recovery.didChangeAppLifecycleState(AppLifecycleState.resumed);await tester.pump(const Duration(milliseconds:500));
  recovery.dispose();check.complete(true);await tester.pump();expect(accepted,0);
 });
}
