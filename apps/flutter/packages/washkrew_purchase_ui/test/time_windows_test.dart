import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';

void main() {
  testWidgets(
    'Pre-start cancellation also keeps the prepaid calendar and only stops renewal',
    (tester) async {
      final now = DateTime.now();
      final p =
          PurchaseSelection(today: DateTime(now.year, now.month, now.day + 5))
            ..mode = PurchaseMode.monthly
            ..confirmed = true
            ..renewalAuthorityGranted = true;
      final dates = p.visits.toList(), windows = p.windowLabel;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) => Scaffold(
              body: RenewalManageCard(
                selection: p,
                onChanged: () => set(() {}),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Cancel subscription'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Paid-cycle refund: ₹0.'), findsOneWidget);
      await tester.tap(find.text('Cancel subscription').last);
      await tester.pumpAndSettle();
      expect(p.autoRenew, isFalse);
      expect(p.renewalAuthorityGranted, isFalse);
      expect(p.confirmed, isTrue);
      expect(p.visits, dates);
      expect(p.windowLabel, windows);
      expect(find.text('Subscription cancelled'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Custom alternatives preserve exact minutes, gaps and the 11 PM example',
    () {
      const w = [
        WashTimeWindow(startMinute: 495, endMinute: 645),
        WashTimeWindow(startMinute: 1140, endMinute: 1380),
      ];
      expect(validateWashWindows(w), isNull);
      expect(w.first.label, '8:15 AM – 10:45 AM');
      expect(w.last.label, '7 PM – 11 PM');
      expect(w.first.toJson(), {'startMinute': 495, 'endMinute': 645});
      final p = PurchaseSelection()
        ..mode = PurchaseMode.monthly
        ..customWindows = List.of(w);
      expect(p.canContinue, isTrue);
      expect(p.windowLabel, '8:15 AM – 10:45 AM, 7 PM – 11 PM');
      final copy = p.snapshot();
      p.customWindows!.clear();
      expect(copy.timeWindows, w);
      expect(p.canContinue, isFalse);
    },
  );
  test(
    'Invalid, overlapping, duplicate, elapsed and overnight windows cannot continue',
    () {
      for (final windows in [
        <WashTimeWindow>[],
        [const WashTimeWindow()],
        [const WashTimeWindow(startMinute: 600, endMinute: 500)],
        [const WashTimeWindow(startMinute: 480, endMinute: 480)],
        [const WashTimeWindow(startMinute: 180, endMinute: 300)],
        [const WashTimeWindow(startMinute: 1200, endMinute: 1440)],
        [
          const WashTimeWindow(startMinute: 480, endMinute: 600),
          const WashTimeWindow(startMinute: 550, endMinute: 650),
        ],
        [
          const WashTimeWindow(startMinute: 480, endMinute: 600),
          const WashTimeWindow(startMinute: 480, endMinute: 600),
        ],
      ]) {
        expect(validateWashWindows(windows), isNotNull);
      }
      expect(
        validateWashWindows([
          const WashTimeWindow(startMinute: 480, endMinute: 600),
        ], notEndedBy: 600),
        isNotNull,
      );
      expect(
        validateWashWindows([
          const WashTimeWindow(startMinute: 480, endMinute: 600),
        ], notEndedBy: 590),
        isNull,
      );
      expect(
        validateWashWindows([
          const WashTimeWindow(startMinute: 480, endMinute: 490),
        ], minimumMinutes: 20),
        isNotNull,
      );
      expect(
        validateWashWindows([
          const WashTimeWindow(startMinute: 480, endMinute: 600),
          const WashTimeWindow(startMinute: 600, endMinute: 720),
        ]),
        isNull,
      );
    },
  );
  testWidgets(
    'Window editor opens minute-precision input and adds/removes drafts',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var windows = [const WashTimeWindow(startMinute: 480, endMinute: 600)];
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) => Scaffold(
              body: SingleChildScrollView(
                child: CustomTimeWindowEditor(
                  windows: windows,
                  onChanged: (v) => set(() => windows = v),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Pressable &&
              (w.label ?? '').startsWith('Window 1 start time'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).at(0), '8');
      await tester.enterText(find.byType(TextField).at(1), '15');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(windows.first.startMinute, 495);
      await tester.tap(find.text('Add another window'));
      await tester.pumpAndSettle();
      expect(windows.length, 2);
      expect(windows.last.complete, isFalse);
      await tester.ensureVisible(find.bySemanticsLabel('Remove window 2'));
      await tester.tap(find.bySemanticsLabel('Remove window 2'));
      await tester.pumpAndSettle();
      expect(windows.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Cancelling subscription keeps paid visits and shows zero current-cycle refund',
    (tester) async {
      final p = PurchaseSelection(today: DateTime(2026, 11, 7))
        ..mode = PurchaseMode.monthly
        ..confirmed = true
        ..renewalAuthorityGranted = true;
      final visits = p.visits.toList();
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, set) => Scaffold(
              body: RenewalManageCard(
                selection: p,
                onChanged: () => set(() {}),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Cancel subscription'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Paid-cycle refund: ₹0.'), findsOneWidget);
      await tester.tap(find.text('Cancel subscription').last);
      await tester.pumpAndSettle();
      expect(p.autoRenew, isFalse);
      expect(p.visits, visits);
      expect(p.confirmed, isTrue);
      expect(find.text('Subscription cancelled'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
