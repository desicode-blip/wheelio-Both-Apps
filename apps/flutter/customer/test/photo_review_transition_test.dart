import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/screens/live.dart';
class LiveFixture extends AppStore{@override bool get isLive=>true;}
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUpAll(()async{final f=FontLoader('packages/washkrew_ui/Roboto')..addFont(rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-Regular.ttf'));await f.load();});
 testWidgets('a server photosReady update replaces Washing with authored Customer photo review',(tester)async{
   tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   final store=LiveFixture(),router=AppRouter(),order=store.sampleOrder(OrderStatus.washing);
   await tester.pumpWidget(AppScope(store:store,router:router,child:const MaterialApp(home:LiveOrderScreen())));await tester.pump();
   expect(find.text('Cleaning'),findsOneWidget);expect(find.byType(CheckWashView),findsNothing);
   store.set(()=>order.status=OrderStatus.photosReady);await tester.pump();await tester.pump();
   expect(find.byType(CheckWashView),findsOneWidget);expect(find.text('Check the wash'),findsOneWidget);expect(find.text('Cleaning'),findsNothing);
   await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
}
