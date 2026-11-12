import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/features/monthly_jobs.dart';
import 'package:washkrew_captain/features/recurring_assignments.dart';
import 'package:washkrew_captain/features/v2_job.dart';
import 'package:washkrew_captain/screens/home.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 (13 Nov): monthly jobs ring on a gold screen; Jobs has One-time / Monthly ways in.
final _key = GlobalKey();
const _dir = String.fromEnvironment('MONTHLY_CAPTURE_DIR');
Future<void> _shot(WidgetTester t, String name) async {
  if (_dir.isEmpty) return;
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1.5);
    final d = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png').writeAsBytesSync(d!.buffer.asUint8List());
  });
}

Widget _screen(R r) => switch (r.n) {
  N.monthlyAlert => MonthlyJobAlertScreen(fromList: r.flag),
  N.recurringList => const RecurringListScreen(),
  N.recurringAssignment => const AssignmentDetailScreen(),
  N.openJobs => OpenJobsScreen(monthly: r.flag),
  _ => WText('route:${r.n.name}', WType.body),
};

class LiveOffers extends CaptainStore {
  @override
  bool get isLive => true;
}

Job _job(String id, {JobExtras extras = JobExtras.none}) =>
    Job(id: id, plate: 'TS 09 AB 1234', type: 'Sedan', isBike: false, pay: 35, tower: 'Tower 1', floor: 'B1', slot: '4', window: '6–8', time: '6:00')..extras = extras;

void main() {
  setUpAll(() async {
    if (_dir.isEmpty) return;
    final l = FontLoader('packages/washkrew_ui/Roboto');
    for (final n in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      l.addFont(rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-$n.ttf'));
    }
    await l.load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test('live offers split into one-time and monthly', () {
    final s = LiveOffers()
      ..liveOffers = [
        _job('a'),
        _job('m', extras: JobExtras(planVisits: 13, planDates: [DateTime(2026, 11, 16), DateTime(2026, 11, 18), DateTime(2026, 11, 20)])),
      ];
    expect(s.oneTimeOffers.map((j) => j.id), ['a']);
    expect(s.monthlyOffers.map((o) => o.id), ['m']);
    expect(s.monthlyOffers.first.visits, 3);
    expect(s.monthlyOffers.first.perVisitPaise, 3500);
    expect(weekdaysOf(s.monthlyOffers.first.assignment.dates), 'Mon, Wed, Fri');
  });

  Future<(CaptainStore, WRouterC)> pump(WidgetTester t, Widget home, {List<R> path = const []}) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = CaptainStore()..signedUp = true;
    final r = WRouterC();
    for (final p in path) {
      r.push(p);
    }
    await t.pumpWidget(RepaintBoundary(
      key: _key,
      child: CaptainScope(store: s, router: r, child: MaterialApp(debugShowCheckedModeBanner: false, home: Material(child: ListenableBuilder(listenable: Listenable.merge([r, s]), builder: (_, _) => WNavStack<R>(router: r, root: home, builder: _screen))))),
    ));
    await t.pump(const Duration(milliseconds: 500));
    return (s, r);
  }

  testWidgets('gold alert: pay per visit, visits, Accept adds it to the calendar', (t) async {
    final (s, r) = await pump(t, const SizedBox(), path: const [R(N.monthlyAlert)]);
    expect(find.text('MONTHLY · RECURRING'), findsOneWidget);
    expect(find.text('₹35'), findsOneWidget);
    expect(find.text('Accept monthly job'), findsOneWidget);
    await _shot(t, 'monthly-alert');
    await t.tap(find.text('Accept monthly job'));
    await t.pump(const Duration(milliseconds: 500));
    expect(s.recurringAccepted, isTrue);
    expect(s.monthlyOffers.length, 1); // the other sample is still open
    // Today's visit (when today is a visit day) joins Today's plan as a recurring job.
    final today = DateTime.now();
    final visitsToday = s.myAssignments.first.assignment.dates.any((d) => d.year == today.year && d.month == today.month && d.day == today.day);
    expect(s.todayJobs.any((j) => j.extras.monthly), visitsToday);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Recurring assignments: list → detail (package, weekday circles) → cancel', (t) async {
    final (s, r) = await pump(t, const SizedBox(), path: const [R(N.recurringList)]);
    for (final o in s.monthlyOffers) {
      s.acceptAssignment(o);
    }
    await t.pumpAndSettle();
    expect(s.myAssignments.length, 2);
    expect(find.byType(WeekdayCircles), findsNWidgets(2));
    await _shot(t, 'recurring-list');
    await t.tap(find.text(s.myAssignments.first.assignment.place));
    await t.pumpAndSettle();
    expect(find.text('Monthly package'), findsOneWidget);
    expect(find.textContaining('per completed visit'), findsNothing);
    await _shot(t, 'recurring-detail');
    await t.tap(find.text('Cancel this recurring job'));
    await t.pumpAndSettle();
    expect(find.textContaining('Cancel at least 2 days ahead'), findsOneWidget);
    await t.tap(find.text('Cancel job'));
    await t.pumpAndSettle();
    expect(s.myAssignments.length, 1);
    expect(s.queue.where((q) => q.id.startsWith('preview-recurring-') && q.day >= 2 && !q.id.startsWith('preview-recurring-2')), isEmpty);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Jobs tab: one Find new jobs banner; the list has gold monthly and normal one-time cards, no timer', (t) async {
    final (s, r) = await pump(t, const JobsTab());
    expect(find.text('Find new jobs'), findsOneWidget);
    expect(find.text('One-time jobs'), findsNothing);
    expect(find.text('Today’s jobs'), findsOneWidget);
    expect(t.getTopLeft(find.text('Find new jobs')).dy, lessThan(t.getTopLeft(find.text('Today’s jobs')).dy));
    await _shot(t, 'jobs-tab');
    r.push(const R(N.openJobs));
    await t.pumpAndSettle();
    expect(find.text('MONTHLY · RECURRING'), findsWidgets);
    expect(find.text('Accept'), findsWidgets);
    expect(find.text('Decide in'), findsNothing); // no timer here
    await _shot(t, 'find-jobs');
    final before = s.oneTimeOffers.length;
    await t.ensureVisible(find.text('Accept').first);
    await t.tap(find.text('Accept').first);
    await t.pump(const Duration(milliseconds: 500));
    expect(s.oneTimeOffers.length, before - 1);
    await t.ensureVisible(find.text('See monthly job').first);
    await t.pumpAndSettle();
    await t.tap(find.text('See monthly job').first);
    await t.pumpAndSettle();
    expect(r.last?.n, N.monthlyAlert);
    expect(r.last?.flag, isTrue); // opened from the list: no ring, no timer
    await t.pumpWidget(const SizedBox());
  });
}
