import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// 13 Nov (Aman): Log out? → loader while the server signs out → first screen → toast.
void main() {
  testWidgets('cancel does nothing; confirm shows a loader, then runs then() and a Logged out toast', (t) async {
    var signedOut = 0, moved = 0;
    final server = Completer<void>();
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => confirmLogOut(context, logOut: () async {
                signedOut++;
                await server.future;
              }, then: () => moved++),
              child: const Text('Log out row'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('Log out row'));
    await t.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(signedOut, 0);

    await t.tap(find.text('Log out row'));
    await t.pumpAndSettle();
    await t.tap(find.text('Log out'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Logging out…'), findsOneWidget);
    expect(signedOut, 1);
    expect(moved, 0); // nothing moves until the server is done
    server.complete();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Logging out…'), findsNothing);
    expect(moved, 1);
    expect(find.text('Logged out'), findsOneWidget);
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Logged out'), findsNothing); // the toast fades away
  });
}
