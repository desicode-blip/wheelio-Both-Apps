import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/src/permission_sequence.dart';

void main(){
 test('permissions are sequential; remembered denials are not requested again',()async{
  final seen=<String>{},calls=<String>[];var running=false;
  Future<void> run()=>runPermissionSequence(alreadyAsked:(name)async=>seen.contains(name),remember:(name)async{seen.add(name);},request:(name)async{expect(running,false);running=true;await Future<void>.delayed(Duration.zero);calls.add(name);running=false;});
  await run();await run();expect(calls,['camera','microphone','location','notifications']);
 });
 test('an interrupted prompt retries later without suppressing other permissions',()async{
  final seen=<String>{},calls=<String>[];
  await runPermissionSequence(alreadyAsked:(name)async=>seen.contains(name),remember:(name)async{seen.add(name);},request:(name)async{calls.add(name);if(name=='camera')throw StateError('Interrupted');});
  expect(seen,{'microphone','location','notifications'});expect(calls.length,4);
 });
}
