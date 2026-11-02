import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/offer_feed.dart';
class Stamp {Stamp(this.value);final DateTime value;DateTime toDate()=>value;}
void main(){
 final now=DateTime(2026,11,2,14);
 Map<String,dynamic> offer(String id,{String mode='live',String status='pending',int seconds=60})=>{'orderId':id,'paymentMode':mode,'status':status,'expiresAt':Stamp(now.add(Duration(seconds:seconds)))};
 test('offers arriving before the profile become visible when mode arrives without another server update',(){
   final feed=CaptainOfferFeed()..records=[offer('live')];expect(feed.pending(now),isEmpty);
   feed.mode='live';expect(feed.pending(now).single['orderId'],'live');
 });
 test('mode first, renewal, withdrawal, expiry and account clearing remain consistent',(){
   final feed=CaptainOfferFeed()..mode='live'..records=[offer('live'),offer('test',mode:'test'),offer('expired',seconds:0),offer('withdrawn',status:'withdrawn')];
   expect(feed.pending(now).map((o)=>o['orderId']),['live']);
   expect(feed.pending(now.add(const Duration(seconds:61))),isEmpty);
   feed.records=[offer('live',seconds:120)];expect(feed.pending(now.add(const Duration(seconds:61))).length,1);
   feed.clear();expect(feed.mode,isNull);expect(feed.records,isEmpty);
 });
}
