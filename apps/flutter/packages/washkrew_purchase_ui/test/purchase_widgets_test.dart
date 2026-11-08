import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';

void main() {
  testWidgets(
    'Days continue without a time; time step requires a slot and preserves days',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = PurchaseSelection(today: DateTime(2026, 11, 7))
        ..mode = PurchaseMode.monthly;
      s.windowStarts.clear();
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlyScheduleScreen(
            selection: s,
            onBack: () {},
            onContinue: () {},
          ),
        ),
      );
      expect(find.text('When is your vehicle free?'), findsNothing);
      expect(tester.widget<WButton>(find.byType(WButton)).enabled, isTrue);
      final days = Set<int>.from(s.weekdays);
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlyTimeScreen(
            selection: s,
            onBack: () {},
            onContinue: () {},
          ),
        ),
      );
      expect(
        tester
            .widget<WButton>(
              find.widgetWithText(WButton, 'Next: check and pay'),
            )
            .enabled,
        isFalse,
      );
      expect(find.byType(CustomTimeWindowEditor), findsOneWidget);
      s.update(
        () => s.customWindows = [
          const WashTimeWindow(startMinute: 495, endMinute: 645),
        ],
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WButton>(
              find.widgetWithText(WButton, 'Next: check and pay'),
            )
            .enabled,
        isTrue,
      );
      expect(s.weekdays, days);
      expect(s.quotePaise, 51700);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Policy dialog shows content and a visible close on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showPlanPolicyPreview(c),
                child: const Text('Policy'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Policy'));
      await tester.pumpAndSettle();
      expect(find.text('Renewal & cancellation'), findsOneWidget);
      expect(find.bySemanticsLabel('Close policy preview'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close policy preview'));
      await tester.pumpAndSettle();
      expect(find.text('Renewal & cancellation'), findsNothing);
      await tester.tap(find.text('Policy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Renewal & cancellation'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Mode, service and coverage stay independent when customer changes choices',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = PurchaseSelection(today: DateTime(2026, 11, 6));
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseChoiceScreen(
            selection: s,
            onBack: () {},
            onContinue: () {},
          ),
        ),
      );
      await tester.tap(find.text('Monthly plan'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Premium'));
      await tester.tap(find.text('Premium'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Exterior + interior'));
      await tester.tap(find.text('Exterior + interior'));
      await tester.pumpAndSettle();
      expect(s.monthly, isTrue);
      expect(s.level, ServiceLevel.premium);
      expect(s.coverage, WashCoverage.exteriorInterior);
      await tester.ensureVisible(find.text('One-time'));
      await tester.tap(find.text('One-time'));
      await tester.pumpAndSettle();
      expect(s.mode, PurchaseMode.once);
      expect(s.level, ServiceLevel.premium);
      expect(s.coverage, WashCoverage.exteriorInterior);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Schedule requires the purchased number of weekdays without changing the price',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = PurchaseSelection(today: DateTime(2026, 11, 6))
        ..mode = PurchaseMode.monthly;
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlyScheduleScreen(
            selection: s,
            onBack: () {},
            onContinue: () => continued = true,
          ),
        ),
      );
      for (final day in ['Mon', 'Wed', 'Fri']) {
        await tester.tap(
          find.descendant(of: find.byType(WChip), matching: find.text(day)),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.widget<WButton>(find.byType(WButton)).enabled, isFalse);
      for (final day in ['Tue', 'Thu', 'Sat']) {
        await tester.tap(
          find.descendant(of: find.byType(WChip), matching: find.text(day)),
        );
        await tester.pumpAndSettle();
      }
      await tester.pumpAndSettle();
      expect(s.frequency, 3);
      expect(s.weekdays.length, 3);
      expect(s.quotePaise, 51700);
      await tester.tap(find.byType(WButton));
      await tester.pumpAndSettle();
      expect(continued, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'All-dates sheet renders the actual visit rows inside the shared scroll sheet',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = PurchaseSelection(today: DateTime(2026, 11, 6))
        ..mode = PurchaseMode.monthly;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: WButton(
                'Open dates',
                onTap: () => showVisitDates(context, s),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open dates'));
      await tester.pumpAndSettle();
      expect(find.text('13 planned visits'), findsOneWidget);
      expect(find.text('Fri, 6 Nov'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Monthly frequency is priced on the choice page for all three services',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = PurchaseSelection(today: DateTime(2026, 11, 6));
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseChoiceScreen(
            selection: s,
            onBack: () {},
            onContinue: () {},
          ),
        ),
      );
      expect(find.byType(FrequencyPicker), findsNothing);
      await tester.tap(find.text('Monthly plan'));
      await tester.pumpAndSettle();
      expect(find.text('3 days a week'), findsOneWidget);
      await tester.ensureVisible(find.byType(FrequencyPicker));
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is WIconButton && w.label == 'More days per week',
        ),
      );
      await tester.pumpAndSettle();
      expect(s.frequency, 4);
      expect(find.text('4 days a week'), findsOneWidget);
      expect(find.text('₹623'), findsOneWidget);
      expect(find.text('₹911'), findsOneWidget);
      expect(find.text('₹1199'), findsOneWidget);
      await tester.ensureVisible(find.text('Extra Premium'));
      await tester.tap(find.text('Extra Premium'));
      await tester.pumpAndSettle();
      expect(find.text('₹1199 / month'), findsOneWidget);
      await tester.ensureVisible(find.text('One-time'));
      await tester.tap(find.text('One-time'));
      await tester.pumpAndSettle();
      expect(find.byType(FrequencyPicker), findsNothing);
      expect(s.frequency, 4);
      expect(s.level, ServiceLevel.extraPremium);
      expect(tester.takeException(), isNull);
    },
  );
}
