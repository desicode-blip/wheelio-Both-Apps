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
 @override Future<void> applyCoupon(String code)async{applies++;draft.couponCode=code;draft.couponAppliedPaise=6900;draft.couponVehicleKind=draft.type!.kind.name;draft.couponBasePricePaise=draft.basePricePaise;changed();}
 // Coupons shown up front on Check and pay (v2 CU-REVIEW, 12 Nov).
 List<Map<String,dynamic>> owned=[{'code':'WK-AABBCCDD-11223344','availablePaise':6900,'status':'active','expiresAt':DateTime.now().add(const Duration(days:30))}];
 @override Stream<List<Map<String,dynamic>>> refundCouponDocs()=>Stream.value(owned);
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
  expect(find.text('Pay now · ₹149'),findsOneWidget);
  await tester.pump();expect(find.byType(TextField),findsNothing);expect(find.text('Your coupons'),findsNothing);
  expect(find.text('₹69 off'),findsOneWidget);expect(store.applies,0);
  await tester.ensureVisible(find.text('Apply'));await tester.tap(find.text('Apply'));await tester.pump();await tester.pump(const Duration(milliseconds:400));
  expect(store.applies,1);expect(store.draft.pricePaise,8000);expect(find.text('Applied to this wash'),findsOneWidget);
  expect(find.text('Pay now · ₹80'),findsOneWidget);
  await tester.ensureVisible(find.text('Remove'));await tester.tap(find.text('Remove'));await tester.pump();await tester.pump(const Duration(milliseconds:400));expect(store.draft.pricePaise,14900);expect(find.text('Apply'),findsOneWidget);
 });
 testWidgets('three or more coupons become one Discount coupons button with a sheet',(tester)async{
  tester.view.physicalSize=const Size(430,1300);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final store=CouponFixture()..draftFull(),router=AppRouter();
  store.owned=[for(final (i,p) in [6900,5000,12000].indexed){'code':'WK-AABBCCDD-1122334$i','availablePaise':p,'status':'active','expiresAt':DateTime.now().add(const Duration(days:30))}];
  await tester.pumpWidget(AppScope(store:store,router:router,child:const MaterialApp(home:ReviewScreen())));await tester.pump();
  expect(find.text('Apply'),findsNothing);expect(find.text('Discount coupons'),findsOneWidget);expect(find.text('3 available · up to ₹120 off'),findsOneWidget);
  await tester.ensureVisible(find.text('Discount coupons'));await tester.tap(find.text('Discount coupons'));await tester.pumpAndSettle();
  expect(find.text('Apply'),findsNWidgets(3));
  await tester.tap(find.text('Apply').first);await tester.pumpAndSettle();
  expect(store.applies,1);expect(find.text('Applied to this wash'),findsOneWidget);expect(find.text('See all 3 coupons'),findsOneWidget);
  await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
}
