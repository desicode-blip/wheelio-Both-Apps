import 'package:flutter/foundation.dart';

/// Availability owns request ordering and selection; the screen owns its design.
class BookingAvailability extends ChangeNotifier {
  String key = '';
  Set<int> available = {}, selected = {};
  bool loading = false, allDay = false;
  String? error;
  int _revision = 0;
  bool _disposed = false;
  bool _pending = false;

  Future<void> load(String nextKey, Future<Set<int>> Function() request, {
    bool refresh = false, Set<int> initial = const {}, bool initialAllDay = false,
  }) async {
    final changed = nextKey != key;
    if (!changed && (!refresh || _pending)) return;
    final revision = ++_revision;
    key = nextKey;
    _pending = true;
    if (changed) {
      available = {};
      selected = {...initial};
      allDay = initialAllDay;
      loading = true;
      error = null;
    }
    notifyListeners();
    try {
      final result = await request();
      if (_disposed || revision != _revision) return;
      available = {...result};
      selected = allDay ? {...available} : selected.intersection(available);
      if (changed && selected.isEmpty && available.isNotEmpty) {
        selected = {(available.toList()..sort()).first};
      }
      // Newly approved capacity can appear after an initially empty response.
      // Leave an explicit cleared selection empty until the user picks again.
      error = null;
    } catch (e) {
      if (_disposed || revision != _revision) return;
      error = e.toString();
      available = {};
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        _pending = false;
        notifyListeners();
      }
    }
  }

  void toggle(int hour) {
    if (!available.contains(hour)) return;
    if (!selected.remove(hour)) selected.add(hour);
    allDay = available.length > 1 && selected.length == available.length;
    notifyListeners();
  }

  void toggleAll() {
    final whole = available.length > 1 && selected.length == available.length;
    allDay = !whole;
    selected = whole ? {} : {...available};
    notifyListeners();
  }

  @override
  void dispose() { _disposed = true; _revision++; super.dispose(); }
}
