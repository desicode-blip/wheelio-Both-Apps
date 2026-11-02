import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/home.dart';
class LiveOffersFixture extends CaptainStore { @override bool get isLive=>true; }
void main(){
  for(final outcome in ['expired','cancelled','taken']){
    testWidgets('live $outcome outcome never invents another Captain assignment',(tester)async{
      final s=LiveOffersFixture()..lastOfferOutcome=outcome,r=WRouterC();
      await tester.pumpWidget(CaptainScope(store:s,router:r,child:const MaterialApp(home:JobMissedScreen())));
      expect(find.text('Job went to someone else'),outcome=='taken'?findsOneWidget:findsNothing);
      expect(find.text(outcome=='cancelled'?'Booking cancelled':outcome=='expired'?'Offer expired':'Job went to someone else'),findsOneWidget);
      await tester.pumpWidget(const SizedBox());s.dispose();r.dispose();
    });
  }
}
