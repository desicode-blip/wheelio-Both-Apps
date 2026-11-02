enum CaptainJobPhase { arrival, ownerNote, identity, beforePhotos, washing, afterPhotos, submitted, cancelled }

/// Resume from confirmed server progress, not from having visited a screen.
CaptainJobPhase? captainJobPhase(Map<String,dynamic>? order){
  if(order==null)return null;
  switch(order['status']){
    case 'cancelled': return CaptainJobPhase.cancelled;
    case 'photosReady':
    case 'approved':
    case 'disputed':
    case 'disputeUpheld': return CaptainJobPhase.submitted;
    case 'washing':
      final evidence=order['evidence'] as Map? ?? {};
      return [0,1,2,3].any((i)=>evidence['after_$i']!=null)
          ? CaptainJobPhase.afterPhotos : CaptainJobPhase.washing;
    case 'onTheWay':
      if(order['arrivedAt']==null)return CaptainJobPhase.arrival;
      final media=order['customerMedia'] as Map? ?? {};
      if((media['note_audio']!=null||media['note_video']!=null)&&order['noteHeard']!=true)return CaptainJobPhase.ownerNote;
      return order['identityStatus']=='verified'?CaptainJobPhase.beforePhotos:CaptainJobPhase.identity;
    default: return null;
  }
}
