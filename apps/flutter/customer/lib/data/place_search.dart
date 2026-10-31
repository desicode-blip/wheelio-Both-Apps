import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

class PlaceSuggestion {
  const PlaceSuggestion(this.id, this.name, this.address);
  final String id, name, address;
  factory PlaceSuggestion.fromMap(Map<String, dynamic> p) => PlaceSuggestion(
    p['placeId'] as String,
    p['name'] as String,
    p['address'] as String? ?? '',
  );
}

/// In-memory search session. Debounce typing, keep nearby matches usable, and
/// ignore replies from previous queries/screens. No GPS/provider data is saved.
class PlaceSearchSession extends ChangeNotifier {
  PlaceSearchSession(this.lookup);
  final Future<List<PlaceSuggestion>> Function(String query, String token)
  lookup;
  static String _newToken() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  String token = _newToken();
  List<PlaceSuggestion> results = [], _nearby = [];
  bool loading = false, _disposed = false;
  Object? error;
  Timer? _debounce;
  int _generation = 0;
  String query = '';
  void completeSelection() {
    _generation++;
    _debounce?.cancel();
    loading = false;
    token = _newToken();
  }

  void search(String value, {bool immediate = false}) {
    query = value.trim();
    _debounce?.cancel();
    final generation = ++_generation;
    error = null;
    results = _nearby
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    loading = query.length != 1;
    notifyListeners();
    if (!loading) return;
    if (immediate) {
      _run(query, generation);
    } else {
      _debounce = Timer(
        const Duration(milliseconds: 350),
        () => _run(query, generation),
      );
    }
  }

  Future<void> _run(String query, int generation) async {
    try {
      final found = await lookup(query, token);
      if (_disposed || generation != _generation) return;
      results = found;
      if (query.isEmpty) _nearby = found;
    } catch (e) {
      if (!_disposed && generation == _generation) error = e;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    super.dispose();
  }
}
