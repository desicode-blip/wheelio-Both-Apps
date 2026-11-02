/// Cache offers independently of the Captain profile. Firestore may deliver the
/// two snapshots in either order; a later profile must re-evaluate saved offers.
class CaptainOfferFeed {
  List<Map<String,dynamic>> records = [];
  String? mode;
  List<Map<String,dynamic>> pending(DateTime now) => [
    for(final offer in records)
      if(mode!=null&&offer['status']=='pending'&&(offer['paymentMode']??'test')==mode&&
        offer['expiresAt']!=null&&(offer['expiresAt'].toDate() as DateTime).isAfter(now))offer,
  ];
  void clear(){records=[];mode=null;}
}
