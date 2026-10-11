import 'package:flutter/widgets.dart';

import '../data/backend.dart';
import '../data/models.dart';
import '../services/device.dart';

/// The booking being built, one small decision per screen
/// (vehicle → plate → photos → place → floor → notes → time → pay).
class BookingDraft {
  VehicleType? type;
  String plate = '';
  final Map<PhotoAngle, PhotoRef> photos = {};
  int? videoSeconds;
  Place? place;
  EntryNote note = const EntryNote();
  TimeSlot? slot;
  bool useFreeWash = false;

  /// Set when the draft started from "Book again".
  bool isRepeat = false;

  int get photosDone => photos.values.where((p) => p.state == UploadState.done).length;
  bool get photosComplete => PhotoAngle.values.every((a) => photos[a]?.state == UploadState.done);
  bool get hasFailedPhoto => photos.values.any((p) => p.state == UploadState.failed);

  int get price => useFreeWash ? 0 : (type?.price ?? 0);

  void startRepeat(Vehicle v) {
    clear();
    type = v.type;
    plate = v.plate;
    place = v.place;
    isRepeat = true;
  }

  void clear() {
    type = null;
    plate = '';
    photos.clear();
    videoSeconds = null;
    place = null;
    note = const EntryNote();
    slot = null;
    useFreeWash = false;
    isRepeat = false;
  }
}

/// App-wide state. Screens read it with `AppScope.of(context)`.
class AppState extends ChangeNotifier {
  AppState(this.backend, this.device);

  final Backend backend;
  final Device device;
  final BookingDraft draft = BookingDraft();

  /// Order being paid for or tracked.
  Order? currentOrder;

  /// Payment method chosen on the pay sheet.
  PaymentMethod? payMethod;

  /// Phone number waiting for an OTP.
  String pendingPhone = '';

  /// Where to go once login finishes (usually the payment sheet).
  String? afterLogin;

  Customer? get customer => backend.currentCustomer;
  bool get isLoggedIn => customer != null;

  void setOrder(Order? o) {
    currentOrder = o;
    notifyListeners();
  }

  void changed() => notifyListeners();
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.notifier!;
  }

  /// Read without subscribing to changes (use in callbacks).
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.notifier!;
  }
}
