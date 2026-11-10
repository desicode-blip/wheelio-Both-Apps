import 'dart:typed_data';

/// The booking is pinned before any picker/network await. Server state is read
/// before uploads so a lost submission response can retry locked evidence.
Future<void> submitProblemReport({
  required String orderId, required String ownerId, required String kind,
  required String note, required List<Uint8List> photos,
  required Future<Map<String,dynamic>?> Function(String) load,
  required Future<void> Function(String,int,Uint8List) upload,
  required Future<void> Function(Map<String,dynamic>) submit,
}) async {
  if(photos.length>3||note.length>1000)throw StateError('Add up to three photos and a description of at most 1,000 characters.');
  final prior=await load(orderId);
  if(prior==null||prior['customerId']!=ownerId)throw StateError('Open this booking from your Bookings to report a problem.');
  final dispute=prior['dispute'];
  if(dispute==null){
    if(!['photosReady','approved'].contains(prior['status']))throw StateError('This wash is not ready for a completion report. Open its tracking screen or contact support.');
    await Future.wait([for(var i=0;i<photos.length;i++)upload(orderId,i,photos[i])]);
  }else if(dispute['kind']!=kind||dispute['note']!=note||(dispute['photos'] as List? ?? []).length!=photos.length){
    throw StateError('A report is already saved for this wash. Open its report status to follow the review.');
  }
  await submit({'orderId':orderId,'kind':kind,'note':note,'photoCount':photos.length});
}
