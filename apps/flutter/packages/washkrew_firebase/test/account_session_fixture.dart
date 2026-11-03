// Controlled SDK snapshots only; never included in a runtime app build.
import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

class SessionUser extends Fake implements User {
 SessionUser(this.uid);@override final String uid;
 @override String get phoneNumber=>'+919000000001';
}
class SessionMeta extends Fake implements SnapshotMetadata {
 SessionMeta(this.isFromCache);@override final bool isFromCache;
 @override bool get hasPendingWrites=>false;
}
// The SDK seals snapshots; this controlled test double never runs in an app.
// ignore: subtype_of_sealed_class
class SessionDoc extends Fake implements DocumentSnapshot<Map<String,dynamic>> {
 SessionDoc(this.value,{this.cached=false});final Map<String,dynamic>? value;final bool cached;
 @override Map<String,dynamic>? data()=>value;
 @override bool get exists=>value!=null;
 @override SnapshotMetadata get metadata=>SessionMeta(cached);
}
class SessionQuery extends Fake implements QuerySnapshot<Map<String,dynamic>> {
 @override List<QueryDocumentSnapshot<Map<String,dynamic>>> get docs=>[];
 @override SnapshotMetadata get metadata=>SessionMeta(false);
}
class AccountSessionFixture extends LiveBackend {
 final authEvents=StreamController<User?>.broadcast();
 final profiles=StreamController<DocumentSnapshot<Map<String,dynamic>>>.broadcast();
 final captains=StreamController<DocumentSnapshot<Map<String,dynamic>>>.broadcast();
 final catalogs=StreamController<DocumentSnapshot<Map<String,dynamic>>>.broadcast();
 final queries=StreamController<QuerySnapshot<Map<String,dynamic>>>.broadcast();
 final wallets=StreamController<DocumentSnapshot<Map<String,dynamic>>>.broadcast();
 final changes=StreamController<void>.broadcast();
 final picture=Completer<Uint8List>();
 String? account;int signOuts=0;
 @override String? get uid=>account;
 @override bool get phoneVerified=>account!=null;
 @override String? get verifiedPhone=>account==null?null:'+919000000001';
 @override bool get supportsPush=>false;
 @override Stream<User?> get sessions=>authEvents.stream;
 @override Stream<DocumentSnapshot<Map<String,dynamic>>> get catalog=>catalogs.stream;
 @override Stream<DocumentSnapshot<Map<String,dynamic>>> profile(String uid)=>profiles.stream;
 @override Stream<DocumentSnapshot<Map<String,dynamic>>> captain(String uid)=>captains.stream;
 @override Stream<QuerySnapshot<Map<String,dynamic>>> orders(String uid,{bool captain=false})=>queries.stream;
 @override Stream<QuerySnapshot<Map<String,dynamic>>> offers(String uid)=>queries.stream;
 @override Stream<QuerySnapshot<Map<String,dynamic>>> earnings(String uid)=>queries.stream;
 @override Stream<QuerySnapshot<Map<String,dynamic>>> inbox(String uid)=>queries.stream;
 @override Stream<DocumentSnapshot<Map<String,dynamic>>> wallet(String uid,String mode)=>wallets.stream;
 @override Stream<void> get availabilityChanges=>changes.stream;
 @override Future<void> registerPush(String role)async{}
 @override Future<Set<String>> uploadedKyc()async=>{};
 @override Future<Uint8List> photo(String path)=>picture.future;
 @override Future<Map<String,dynamic>> call(String name,[Map<String,dynamic> data=const {}])async=>{};
 @override Future<void> signOut()async{signOuts++;account=null;authEvents.add(null);}
 void login(String uid){account=uid;authEvents.add(SessionUser(uid));}
 void profileValue(Map<String,dynamic>? value,{bool cached=false})=>profiles.add(SessionDoc(value,cached:cached));
 void captainValue(Map<String,dynamic>? value,{bool cached=false})=>captains.add(SessionDoc(value,cached:cached));
 Future<void> close()async{for(final c in <StreamController>[authEvents,profiles,captains,catalogs,queries,wallets,changes]){await c.close();}}
}
