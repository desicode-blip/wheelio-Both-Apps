import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/screens/auth_pay.dart';
import 'package:washkrew_customer/screens/booking_ai_setting.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

class AiSettingFixture extends AppStore {
  @override bool get isLive=>true;
  final saved=Completer<void>();
  int calls=0;
  bool fail=false;
  @override Future<bool> setBookingPhotoAi(Order order,bool enabled) async {
    calls++;
    if(fail)throw StateError('Cannot save');
    await saved.future;
    set((){order.aiPhotoCheckEnabled=enabled;order.aiPhotoCheckRevision++;});
    return false;
  }
}
void main(){
  setUpAll(()async{final font=FontLoader('packages/washkrew_ui/Roboto')..addFont(rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-Regular.ttf'));await font.load();});
  testWidgets('post-payment toggle saves before showing ON and permits OFF without a popup',(tester)async{
    final store=AiSettingFixture(),router=AppRouter(),o=store.sampleOrder(OrderStatus.searching)..paymentStatus='captured';
    await tester.pumpWidget(AppScope(store:store,router:router,child:MaterialApp(home:StatefulBuilder(builder:(context,setState)=>AnimatedBuilder(animation:store,builder:(_,_)=>BookingAiPhotoSetting(order:o))))));
    expect(tester.widget<WToggle>(find.byType(WToggle)).on,false);
    await tester.tap(find.byType(WToggle));await tester.pump();
    expect(store.calls,1);expect(tester.widget<WToggle>(find.byType(WToggle)).on,false);expect(tester.widget<WToggle>(find.byType(WToggle)).enabled,false);
    expect(find.text('Allow Google AI photo check?'),findsNothing);
    store.saved.complete();await tester.pumpAndSettle();expect(tester.widget<WToggle>(find.byType(WToggle)).on,true);
    await tester.tap(find.byType(WToggle));await tester.pumpAndSettle();expect(store.calls,2);expect(o.aiPhotoCheckEnabled,false);
    await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
  });
  testWidgets('unpaid and finished bookings do not offer an editable AI toggle; failed saves do not grant permission',(tester)async{
    final store=AiSettingFixture()..fail=true,router=AppRouter(),o=store.sampleOrder(OrderStatus.searching);
    Future<void> render()async{await tester.pumpWidget(AppScope(store:store,router:router,child:MaterialApp(home:BookingAiPhotoSetting(order:o))));await tester.pump();}
    await render();expect(find.byType(WToggle),findsNothing);
    o.paymentStatus='captured';await render();await tester.tap(find.byType(WToggle));await tester.pumpAndSettle();expect(o.aiPhotoCheckEnabled,false);
    o.status=OrderStatus.photosReady;await render();expect(find.byType(WToggle),findsNothing);
    await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
  });
  testWidgets('the payment-success screen contains the new toggle',(tester)async{
    final store=AiSettingFixture(),router=AppRouter();final o=store.sampleOrder(OrderStatus.searching);o.paymentStatus='captured';
    await tester.pumpWidget(AppScope(store:store,router:router,child:const MaterialApp(home:BookedScreen())));await tester.pump();
    expect(find.text('AI wash photo check'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
  });
}
