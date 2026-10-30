/// Shares slot requests without sharing capacity across account/catalog changes.
class BookingAvailabilityCache {
  BookingAvailabilityCache({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const lifetime = Duration(seconds: 45);
  final DateTime Function() _now;
  final Map<String, _AvailabilityRequest> _requests = {};
  String _context = '';
  int _generation = 0;

  void setContext(String value) {
    if (_context == value) return;
    _context = value;
    clear();
  }

  void clear() {
    _generation++;
    _requests.clear();
  }

  Future<Set<int>> load(String key, Future<Set<int>> Function() request, {bool fresh = false}) {
    final now = _now();
    _requests.removeWhere((_, entry) {
      final completed = entry.completedAt;
      if (completed == null) return false;
      final age = now.difference(completed);
      return age.isNegative || age >= lifetime;
    });
    final hit = _requests[key];
    // Even an explicit refresh can join an in-flight request for this context.
    if (hit != null && (hit.completedAt == null || !fresh)) return hit.result;

    final generation = _generation, entry = _AvailabilityRequest();
    _requests[key] = entry;
    entry.result = Future<Set<int>>.sync(request).then((hours) {
      if (generation != _generation) throw StateError('Availability changed. Please retry.');
      entry.completedAt = _now();
      return Set<int>.unmodifiable(hours);
    }).catchError((Object error, StackTrace stack) {
      if (identical(_requests[key], entry)) _requests.remove(key);
      Error.throwWithStackTrace(error, stack);
    });
    return entry.result;
  }
}

class _AvailabilityRequest {
  late final Future<Set<int>> result;
  DateTime? completedAt;
}
