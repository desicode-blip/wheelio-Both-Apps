import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/evidence_uploads.dart';

void main(){
  test('four captures send concurrently; workflow waits for all confirmed uploads',()async{
    final queue=EvidenceUploads((){}),gates=[for(var i=0;i<4;i++)Completer<void>()];
    var started=0,finished=false;
    for(var i=0;i<4;i++){queue.add('job/before_$i',Uint8List.fromList([i]),(){started++;return gates[i].future;});}
    expect(started,4);
    final barrier=queue.flush([for(var i=0;i<4;i++)'job/before_$i']).then((_)=>finished=true);
    for(var i=0;i<3;i++){gates[i].complete();}
    await Future<void>.delayed(Duration.zero);expect(finished,false);
    gates[3].complete();await barrier;expect(finished,true);
    expect(queue.entries.values.every((e)=>e.state==EvidenceSendState.done),true);
  });
  test('failure retains the actual capture; retry shares the upload and job keys stay independent',()async{
    final queue=EvidenceUploads((){}),bytes=Uint8List.fromList([1,2,3]),retry=Completer<void>();
    var calls=0;
    queue.add('first/after_0',bytes,(){calls++;return calls==1?Future.error(StateError('network')):retry.future;});
    await Future<void>.delayed(Duration.zero);
    expect(queue.entries['first/after_0']!.state,EvidenceSendState.failed);
    expect(queue.entries['first/after_0']!.bytes,same(bytes));
    final one=queue.retry('first/after_0'),two=queue.retry('first/after_0');
    expect(calls,2);
    queue.add('second/after_0',Uint8List.fromList([4]),()async{});
    retry.complete();await Future.wait([one,two]);
    expect(queue.entries.length,2);expect(calls,2);
    queue.clear();expect(queue.entries,isEmpty);
  });
}
