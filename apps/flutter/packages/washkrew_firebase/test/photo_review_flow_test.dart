import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/src/photo_review_flow.dart';
void main(){
 test('an old server is probed read-only and cannot receive a new AI request',()async{
   final calls=<bool>[];
   await expectLater(runPhotoReview(requiredConsentVersion:'vehicle-after-photos-v1',invoke:(read)async{calls.add(read);return {'status':'notChecked'};},canReconcile:(_)=>true),throwsStateError);
   expect(calls,[true]);
 });
 test('lost manual-review response recovers without another AI request',()async{
   final calls=<bool>[];
   final result=await runPhotoReview(invoke:(read)async{calls.add(read);if(!read)throw StateError('lost');return {'status':'manualReview','issues':[]};},canReconcile:(_)=>true,wait:(_)async{});
   expect(result['status'],'manualReview');expect(calls,[false,true]);
 });
 test('lost response uses server review without another inference or fabricated result',()async{
   final calls=<bool>[];var reads=0;
   final result=await runPhotoReview(invoke:(read)async{calls.add(read);if(!read)throw StateError('lost response');return ++reads<3?{'status':'checking'}:{'status':'checked','issues':[]};},canReconcile:(_)=>true,wait:(_)async{});
   expect(result['status'],'checked');expect(calls,[false,true,true,true]);
 });
 test('unavailable advice is not clean success; permission errors and unchanged missing checks do not reconcile',()async{
   final result=await runPhotoReview(invoke:(read)async{if(!read)throw StateError('lost');return {'status':'unavailable','issues':[{'side':0,'reason':'Review manually'}]};},canReconcile:(_)=>true);
   expect(result['issues'],isNotEmpty);
   var calls=0;
   await expectLater(runPhotoReview(invoke:(_)async{calls++;throw StateError('unauthorized');},canReconcile:(_)=>false),throwsStateError);expect(calls,1);
   await expectLater(runPhotoReview(invoke:(read)async{if(!read)throw StateError('offline');return {'status':'notChecked'};},canReconcile:(_)=>true),throwsStateError);
 });
}
