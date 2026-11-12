import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/features/wash_journey.dart';
import 'package:washkrew_captain/screens/money.dart';

// v2 CA-JOURNEY (12 Nov): My level goes past the first 3 days to wash milestones.
class JourneyStore extends CaptainStore {
  JourneyStore(this.washes, {this.status = 'active'});
  final int washes;
  final String status;
  @override
  bool get isLive => true;
  @override
  Map<String, dynamic> get liveCaptain => {'completedWashes': washes, 'workStatus': status, 'ratingCount': 3};
}

Future<void> _open(WidgetTester t, CaptainStore s) async {
  t.view.physicalSize = const Size(430, 2000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(CaptainScope(store: s, router: WRouterC(), child: const MaterialApp(home: LevelScreen())));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('active Captain: washes, next milestone and its reward, no 3-day card', (t) async {
    final s = JourneyStore(73);
    await _open(t, s);
    expect(find.text('73'), findsOneWidget);
    expect(find.text('27 more to 100 washes'), findsOneWidget);
    expect(find.text('Surprise WashKrew merchandise'), findsNWidgets(2)); // next reward + its stop
    expect(find.textContaining('New captain: day'), findsNothing);
    expect(find.text('Reached · Badge'), findsOneWidget); // 50
    expect(find.text('2000 washes'), findsOneWidget);
    expect(s.levelSummary, '73 washes · next 100');
    expect(t.takeException(), isNull);
  });
  testWidgets('first days keep the 3-day card above the journey', (t) async {
    final s = JourneyStore(3, status: 'probation');
    await _open(t, s);
    expect(find.textContaining('New captain: day'), findsOneWidget);
    expect(find.text('47 more to 50 washes'), findsOneWidget);
    expect(s.levelSummary, startsWith('Day '));
  });
  test('server milestones replace the defaults, sorted', () {
    final s = JourneyStore(0)..liveConfig = {'captainMilestones': [{'washes': 300, 'title': 'B', 'reward': 'Cap'}, {'washes': 20, 'title': 'A'}]};
    expect(s.washMilestones.map((m) => m.washes), [20, 300]);
    expect(s.washMilestones.first.reward, isNull);
  });
}
