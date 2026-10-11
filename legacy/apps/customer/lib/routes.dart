import 'data/models.dart';

/// One route per screen ID (design read-me: "One route per screen ID").
/// Letter suffixes (b, c) are states of the same screen, reached through
/// data or `?state=` and are not separate routes.
abstract final class R {
  static const splash = '/c01'; // C01-Splash
  static const welcome = '/c02'; // C02-Welcome
  static const vehicleType = '/c05'; // C05, C52 (200% text)
  static const vehicleNumber = '/c06'; // C06, C06b
  static const photos = '/c07'; // C07, C07b, C07c
  static const camera = '/c08'; // C08, C08b
  static const location = '/c09'; // C09, C09b
  static const addressSearch = '/c09c'; // C09c
  static const floorSlot = '/c10'; // C10
  static const entryNotes = '/c11'; // C11
  static const timeSlot = '/c12'; // C12, C12b
  static const review = '/c13'; // C13
  static const login = '/c14'; // C14, C14b
  static const otp = '/c15'; // C15, C15b, C15c
  static const name = '/c16'; // C16
  static const payMethod = '/c17'; // C17, CA3, CA4
  static const paying = '/c18'; // C18, C18b, C18c
  static const booked = '/c19'; // C19
  static const whatsApp = '/c19b'; // C19b (reference only)
  static const searching = '/c20'; // C20
  static const noWasher = '/c21'; // C21
  static const onTheWay = '/c22'; // C22, C22b, C24, C30
  static const washing = '/c23'; // C23
  static const checkPhotos = '/c25'; // C25
  static const photoCompare = '/c26'; // C26
  static const rate = '/c27'; // C27
  static const autoApproved = '/c28'; // C28
  static const cancel = '/c29'; // C29, C29c
  static const cancelled = '/c29b'; // C29b
  static const reportProblem = '/c31'; // C31
  static const problemPhotos = '/c32'; // C32
  static const disputeSent = '/c33'; // C33
  static const disputeDecision = '/c34'; // C34, C35, C36
  static const refund = '/c37'; // C37
  static const home = '/c40'; // C40, C41, C42, C55, CA1
  static const bookings = '/c43'; // C43, C43b, C43c
  static const bookingDetail = '/c44'; // C44
  static const repeat = '/c45'; // C45
  static const vehicles = '/c46'; // C46
  static const profile = '/c47'; // C47, C53
  static const help = '/c48'; // C48
  static const notifyAsk = '/c49'; // C49
  static const offline = '/c50'; // C50
  static const error = '/c51'; // C51
  static const sessionExpired = '/c54'; // C54

  /// Developer screen gallery (mock mode only).
  static const gallery = '/dev';
}

/// Where a live order should be shown for its current status.
String liveRouteFor(Order o) {
  switch (o.status) {
    case OrderStatus.pendingPayment:
      return R.payMethod;
    case OrderStatus.paymentPending:
      return '${R.paying}?state=pending';
    case OrderStatus.searching:
      return R.searching;
    case OrderStatus.onTheWay:
      return R.onTheWay;
    case OrderStatus.washing:
      return R.washing;
    case OrderStatus.photosReady:
      return R.checkPhotos;
    case OrderStatus.approved:
      return o.rating == null ? R.rate : R.home;
    case OrderStatus.autoApproved:
      return R.autoApproved;
    case OrderStatus.cancelled:
      return R.cancelled;
    case OrderStatus.noWasher:
      return R.noWasher;
    case OrderStatus.disputed:
      return o.dispute?.outcome == DisputeOutcome.damagePriority ? R.disputeDecision : R.disputeSent;
    case OrderStatus.disputeUpheld:
    case OrderStatus.disputeRejected:
      return R.disputeDecision;
  }
}
