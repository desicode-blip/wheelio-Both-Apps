import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/screens/common.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_customer/screens/coupons.dart';

class CouponFixture extends AppStore{
 @override bool get isLive=>true;
 int applies=0;
 @override Future<void> applyCoupon(String code)async{applies++;draft.couponCode='WK-AABBCCDD-11223344';draft.couponAppliedPaise=6900;draft.couponVehicleKind=draft.type!.kind.name;draft.couponBasePricePaise=draft.basePricePaise;changed();}
}
void main(){
 testWidgets('Home opens owned coupons with no wallet balance or top-up entry',(tester)async{
  final store=CouponFixture(),router=AppRouter();
  await tester.pumpWidget(AppScope(store:store,router:router,child:const MaterialApp(home:Scaffold(body:CouponsButton()))));
  expect(find.text('Coupons'),findsOneWidget);expect(find.textContaining('Wallet'),findsNothing);
  await tester.tap(find.text('Coupons'));expect(router.last?.n,N.coupons);
  await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
 testWidgets('owned coupons require login and return to coupons after OTP',(tester)async{
  final store=CouponFixture(),router=AppRouter()..push(const R(N.coupons));
  await tester.pumpWidget(AppScope(store:store,router:router,child:const MaterialApp(home:CouponsScreen())));
  expect(find.text('Log in to view coupons'),findsOneWidget);await tester.tap(find.text('Log in to view coupons'));
  expect(router.last?.n,N.login);router.finishLogin(reviewOnly:true);expect(router.last?.n,N.coupons);
  await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
 testWidgets('legacy wallet/free-wash values cannot silently make a new checkout free; coupon applies only explicitly',(tester)async{
  tester.view.physicalSize=const Size(430,1300);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final store=CouponFixture()..draftFull()..customer=(Customer(id:'owner',phone:'',freeWashes:2)..credit=10000),router=AppRouter();
  await tester.pumpWidget(AppScope(store:store,router:router,child:const MaterialApp(home:ReviewScreen())));await tester.pump();
  expect(store.draft.pricePaise,14900);expect(store.draft.useFreeWash,false);expect(store.draft.creditApplied,0);
  expect(find.textContaining('Pay by wallet'),findsNothing);expect(find.text('Top up'),findsNothing);
  expect(find.text('Pay via Razorpay · ₹149'),findsOneWidget);
  final input=find.widgetWithText(TextField,'WK-XXXXXXXX-XXXXXXXX');await tester.ensureVisible(input);await tester.enterText(input,'WK-AABBCCDD-11223344');await tester.pump();
  await tester.ensureVisible(find.text('Apply coupon'));await tester.tap(find.text('Apply coupon'));await tester.pump();expect(store.applies,1);expect(store.draft.pricePaise,8000);
  expect(find.text('Pay via Razorpay · ₹80'),findsOneWidget);
  await tester.ensureVisible(find.text('Remove coupon'));await tester.tap(find.text('Remove coupon'));await tester.pump();expect(store.draft.pricePaise,14900);
  await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
}
