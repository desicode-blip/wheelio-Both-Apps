// Navigation stack driven by a list of routes, like SwiftUI's NavigationStack(path:).
// Screens slide in from the right (iOS style) on every platform.

import 'package:flutter/cupertino.dart';

import 'fmt.dart';

class NavEntry<R> {
  NavEntry(this.route) : key = newId('r');
  final String key;
  final R route;
}

/// The path of pushed screens plus the selected tab.
class WRouter<R> extends ChangeNotifier {
  List<NavEntry<R>> path = [];
  int _tab = 0;

  int get tab => _tab;
  set tab(int t) {
    _tab = t;
    notifyListeners();
  }

  R? get last => path.isEmpty ? null : path.last.route;

  void push(R r) {
    path = [...path, NavEntry(r)];
    notifyListeners();
  }

  void pop() {
    if (path.isEmpty) return;
    path = path.sublist(0, path.length - 1);
    notifyListeners();
  }

  void popToRoot() {
    path = [];
    notifyListeners();
  }

  void replace(List<R> routes) {
    path = [for (final r in routes) NavEntry(r)];
    notifyListeners();
  }

  /// Keep the first [count] screens.
  void keep(int count) {
    path = path.sublist(0, count.clamp(0, path.length));
    notifyListeners();
  }

  /// Replace the top screen (dropLast + append).
  void swapTop(R r) {
    path = [...path.sublist(0, path.isEmpty ? 0 : path.length - 1), NavEntry(r)];
    notifyListeners();
  }

  void removeKey(String key) {
    if (!path.any((e) => e.key == key)) return;
    path = path.where((e) => e.key != key).toList();
    notifyListeners();
  }
}

/// Renders the root screen plus every pushed screen. Lower screens stay alive (their state
/// survives, like SwiftUI) and the top one animates in and out.
class WNavStack<R> extends StatelessWidget {
  const WNavStack({super.key, required this.router, required this.root, required this.builder});
  final WRouter<R> router;
  final Widget root;
  final Widget Function(R route) builder;

  @override
  Widget build(BuildContext context) => Navigator(
        pages: [
          CupertinoPage(key: const ValueKey('root'), child: root),
          for (final e in router.path) CupertinoPage(key: ValueKey(e.key), child: builder(e.route)),
        ],
        onDidRemovePage: (page) {
          final k = page.key;
          if (k is ValueKey<String> && k.value != 'root') router.removeKey(k.value);
        },
      );
}

/// True while this screen is the top of the stack (SwiftUI onAppear / onDisappear).
bool isTopScreen(BuildContext context) => ModalRoute.of(context)?.isCurrent ?? true;

/// Runs [onAppear] whenever the screen becomes the top of the stack, and [onDisappear]
/// when something covers it or it goes away.
class OnAppear extends StatefulWidget {
  const OnAppear({super.key, required this.child, this.onAppear, this.onDisappear});
  final Widget child;
  final VoidCallback? onAppear;
  final VoidCallback? onDisappear;
  @override
  State<OnAppear> createState() => _OnAppearState();
}

class _OnAppearState extends State<OnAppear> {
  bool? _top;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final top = isTopScreen(context);
    if (top == _top) return;
    _top = top;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (top) {
        widget.onAppear?.call();
      } else {
        widget.onDisappear?.call();
      }
    });
  }

  @override
  void dispose() {
    if (_top == true) {
      final cb = widget.onDisappear;
      WidgetsBinding.instance.addPostFrameCallback((_) => cb?.call());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
