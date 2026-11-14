import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';
import '../data/store.dart';
import 'parts.dart';
import 'help.dart' show WorkSlotsEditor;

/// Owner-authorized coverage editor. The saved centre is independent of job GPS.
class ServiceAreaScreen extends StatefulWidget {
  const ServiceAreaScreen({super.key, this.setup = false});
  final bool setup;
  @override
  State<ServiceAreaScreen> createState() => _ServiceAreaScreenState();
}

class _ServiceAreaScreenState extends State<ServiceAreaScreen> {
  double? latitude, longitude;
  int radius = 3, generation = 0;
  static String _newToken() {
    final random=Random.secure();
    return List.generate(32,(_)=>'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)]).join();
  }
  String label='',query='',token=_newToken();
  bool loaded = false, locating = false, searching = false, saving = false;
  /// 14 Nov (Aman): two steps, like the Customer app's "Is your vehicle here?":
  /// 0 = where you work (map, found by GPS as the screen opens), 1 = working hours.
  int page = 0;
  /// Typing an area instead of GPS (or "Change" on the map).
  bool searchMode = false, locateFailed = false;
  String? error;
  Timer? debounce;
  List<Map<String, dynamic>> suggestions = [];
  List<WorkSlot> slots = [];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    loaded = true;
    final store = context.store, a = store.liveCaptain['serviceArea'];
    if (a is Map) {
      latitude = (a['center']?['latitude'] as num?)?.toDouble();
      longitude = (a['center']?['longitude'] as num?)?.toDouble();
      radius = (a['radiusKm'] as num?)?.toInt() ?? 3;
      label = a['label'] as String? ?? '';
    }
    slots = store.workSlots.isNotEmpty
        ? [...store.workSlots]
        : [
            store.hasServiceArea
                ? (workDayStart, workDayEnd)
                : (9 * 60, 18 * 60),
          ];
    // "Use current location" is already pressed: GPS runs as soon as the screen opens.
    if (latitude == null) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) locate(); });
  }

  @override
  void dispose() {
    generation++;
    debounce?.cancel();
    super.dispose();
  }

  Future<void> locate() async {
    if (locating) return;
    final store = context.store;
    setState(() {
      locating = true;
      locateFailed = false;
      error = null;
    });
    try {
      final p = await store.live!.currentPosition();
      if (mounted) {
        setState(() {
          latitude = p.latitude;
          longitude = p.longitude;
          if (label.isEmpty) label = 'My work area';
          searchMode = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { locateFailed = true; if (latitude != null) error = backendError(e); });
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void search(String value) {
    final g = ++generation;
    debounce?.cancel();
    setState(() {
      query = value;
      error = null;
      suggestions = [];
      searching = value.trim().length >= 2;
    });
    if (value.trim().length < 2) return;
    debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await context.store.live!.call('searchPlaceSuggestions', {
          'query': value.trim(),
          'sessionToken': token,
          if (latitude != null)
            'origin': {'latitude': latitude, 'longitude': longitude},
        });
        if (mounted && g == generation) {
          setState(
            () => suggestions = [
              for (final p in r['suggestions'] as List)
                Map<String, dynamic>.from(p as Map),
            ],
          );
        }
      } catch (e) {
        if (mounted && g == generation) setState(() => error = backendError(e));
      } finally {
        if (mounted && g == generation) setState(() => searching = false);
      }
    });
  }

  Future<void> select(Map<String, dynamic> p) async {
    final g = ++generation;
    debounce?.cancel();
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final r = await context.store.live!.call('selectPlaceSuggestion', {
        'placeId': p['placeId'],
        'sessionToken': token,
      });
      if (!mounted || g != generation) return;
      final place = r['place'] as Map;
      setState(() {
        latitude = (place['latitude'] as num).toDouble();
        longitude = (place['longitude'] as num).toDouble();
        label = place['name'] as String;
        query = label;
        suggestions = [];
        searchMode = false;
        token=_newToken();
      });
    } catch (e) {
      if (mounted && g == generation) setState(() => error = backendError(e));
    } finally {
      if (mounted && g == generation) setState(() => searching = false);
    }
  }

  Future<void> save() async {
    if (saving || latitude == null) return;
    final store = context.store, router = context.router;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await store.live!.call('saveCaptainServiceArea', {
        'center': {'latitude': latitude, 'longitude': longitude},
        'radiusKm': radius,
        'label': label,
        'workingSlots': [
          for (final s in mergeSlots(slots))
            {'startMinute': s.$1, 'endMinute': s.$2},
        ],
      });
      if (!mounted) return;
      store.set(() {
        store.liveCaptain['serviceArea'] = result['serviceArea'];
        store.workSlots = mergeSlots(slots);
        store.refreshKycSteps();
        store.toast = 'Serving area saved';
      });
      if (widget.setup) {
        // 14 Nov (Aman): straight on to the next step, not back to Home.
        final next = !store.hasProfileName ? const R(N.signUp, index: 2) : switch (store.nextStep) {
          KycStep.aadhaar => const R(N.aadhaar),
          KycStep.photo => const R(N.selfie),
          KycStep.bank => const R(N.bank),
          KycStep.training => const R(N.training),
          KycStep.quiz => const R(N.quiz),
          KycStep.area => null,
          null => store.underReview ? null : const R(N.rules),
        };
        router.replace([const R(N.steps), ?next]);
      } else {
        router.pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = backendError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => page == 1 ? _hours(context) : _where(context);

  /// Step 2: working hours, then save.
  Widget _hours(BuildContext context) => WScreen(
    canvas: true,
    gutter: WSpace.gutterCaptain,
    header: WHeader(title: 'Working hours', help: false, onBack: () => setState(() { page = 0; error = null; })),
    footer: WFooter(
      child: WButton(
        saving ? 'Saving…' : widget.setup ? 'Save and continue' : 'Save serving area',
        size: ButtonSize.captain,
        enabled: !saving && latitude != null && label.trim().length >= 2,
        onTap: save,
      ),
    ),
    children: [
      const WTitle('When do you work?', top: 10),
      const WBody('Set the hours when customers can book you. Drag the sun and moon, or the slider.', top: 4, bottom: 12),
      WorkSlotsEditor(slots: slots, onChanged: (v) => setState(() => slots = v)),
      if (error != null)
        Padding(padding: const EdgeInsets.only(top: 16), child: WText(error!, WType.body, color: WColor.destructive)),
      const SizedBox(height: 24),
    ],
  );

  /// Step 1: where you work. Same flow as the Customer app's location step.
  Widget _where(BuildContext context) {
    final store = context.store;
    const header = WHeader(title: 'Serving area', help: false);
    // Finding the phone's location as the screen opens.
    if (latitude == null && !searchMode && (locating || !locateFailed)) {
      return const WScreen(scrolls: false, canvas: true, header: header, children: [
        Expanded(child: WFullState(icon: WIcon.location, title: 'Finding your location…', message: 'The centre of your work area. You can move it next.', spinning: true, captain: true)),
      ]);
    }
    // GPS is off or refused: turn it on, or search instead.
    if (latitude == null && !searchMode) {
      return WScreen(scrolls: false, canvas: true, header: header, children: [
        Expanded(
          child: WFullState(
            icon: WIcon.location,
            tone: Tone.wait,
            title: 'Location is off',
            message: 'We use it once to set the centre of your work area. Your exact centre stays private. You can also search for your area.',
            primary: 'Turn on location',
            secondary: 'Search area',
            captain: true,
            onPrimary: locate,
            onSecondary: () => setState(() => searchMode = true),
          ),
        ),
      ]);
    }
    if (searchMode) {
      return WScreen(
        canvas: true,
        gutter: WSpace.gutterCaptain,
        header: WHeader(title: 'Serving area', help: false, onBack: latitude == null ? null : () => setState(() => searchMode = false)),
        children: [
          const WTitle('Search your work area', top: 10),
          const WBody('An area, society or landmark at the centre of where you want jobs.', top: 4, bottom: 16),
          WTextField(label: 'Search area or building', large: true, value: query, placeholder: 'Type an area, society or landmark', onChanged: search),
          const SizedBox(height: 8),
          WListRow(icon: WIcon.location, title: locating ? 'Finding your location…' : 'Use current location', onTap: locate),
          if (searching) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          for (final p in suggestions)
            WListRow(icon: WIcon.location, title: p['name'] as String, subtitle: p['address'] as String? ?? '', onTap: () => select(p)),
          if (suggestions.isNotEmpty) const Padding(padding: EdgeInsets.only(bottom: 12), child: WText('Google Maps', WType.caption)),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 16), child: WText(error!, WType.body, color: WColor.destructive)),
        ],
      );
    }
    return WScreen(
      canvas: true,
      gutter: 0,
      header: header,
      footer: WFooter(
        child: WButton('Yes, I’ll work here', size: ButtonSize.captain, enabled: label.trim().length >= 2, onTap: () => setState(() { page = 1; error = null; })),
      ),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: WSpace.gutterCaptain),
          child: WTitleBlock('Where will you work?', subtitle: 'Drag the map to move the centre. Homes inside the circle can book you.'),
        ),
        SizedBox(
          height: 330,
          child: LivePlaceMap(
            config: Map<String, dynamic>.from(store.liveConfig['maps'] as Map? ?? {}),
            latitude: latitude!,
            longitude: longitude!,
            radiusKm: radius.toDouble(),
            onMoved: (a, b) => setState(() { latitude = a; longitude = b; }),
            onLocate: () async {
              await locate();
              return latitude == null ? null : (latitude!, longitude!);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(WSpace.gutterCaptain, 18, WSpace.gutterCaptain, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            WCard(
              outlined: true,
              child: Row(children: [
                const WIconBox(WIcon.location, size: 44, radius: 10),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  WText(label, WType.title),
                  const WText('Centre of your work area · private', WType.caption),
                ])),
                WLink('Change', onTap: () => setState(() { searchMode = true; query = ''; suggestions = []; })),
              ]),
            ),
            const SizedBox(height: 12),
            WCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: WText('Travel radius', WType.title)),
                  WText('$radius km', WType.title, color: WColor.primary),
                ]),
                SizedBox(
                  height: 64,
                  child: Slider(
                    value: radius.toDouble(), min: 1, max: 10, divisions: 9, label: '$radius km',
                    activeColor: WColor.primary,
                    onChanged: (v) => setState(() => radius = v.round()),
                  ),
                ),
                const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [WText('1 km', WType.caption), WText('10 km', WType.caption)]),
              ]),
            ),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 16), child: WText(error!, WType.body, color: WColor.destructive)),
            const SizedBox(height: 24),
          ]),
        ),
      ],
    );
  }
}
