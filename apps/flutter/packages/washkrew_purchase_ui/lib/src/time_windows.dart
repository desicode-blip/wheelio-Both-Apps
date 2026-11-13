import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

/// Minute-precision availability, not a guaranteed arrival appointment.
/// Null endpoints exist only while editing; never send an incomplete draft.
class WashTimeWindow {
  const WashTimeWindow({this.startMinute, this.endMinute});
  final int? startMinute, endMinute;
  bool get complete => startMinute != null && endMinute != null;
  String get label => complete
      ? '${formatWashMinute(startMinute!)} – ${formatWashMinute(endMinute!)}'
      : 'Choose times';
  Map<String, int> toJson() {
    if (validateWashWindows([this]) != null)
      throw StateError('Invalid time window');
    return {'startMinute': startMinute!, 'endMinute': endMinute!};
  }

  @override
  bool operator ==(Object other) =>
      other is WashTimeWindow &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;
  @override
  int get hashCode => Object.hash(startMinute, endMinute);
}

String formatWashMinute(int minute) {
  final h = minute ~/ 60, m = minute % 60;
  return '${h % 12 == 0 ? 12 : h % 12}${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'} ${h < 12 ? 'AM' : 'PM'}';
}

List<WashTimeWindow> orderedWashWindows(Iterable<WashTimeWindow> windows) =>
    windows.toList()
      ..sort((a, b) => (a.startMinute ?? -1).compareTo(b.startMinute ?? -1));
/// v2 CU-WASHCHOICE (8 Nov, Aman): service hours and the shortest window. The
/// Customer app passes the server's hours when it has them.
const washDayStartMinute = 240; // 4 AM
const washDayEndMinute = 1380; // 11 PM
const washMinimumWindowMinutes = 60; // at least 1 hour

String? validateWashWindows(
  List<WashTimeWindow> windows, {
  int earliest = washDayStartMinute,
  int latest = washDayEndMinute,
  int minimumMinutes = washMinimumWindowMinutes,
  int? notEndedBy,
}) {
  if (windows.isEmpty) return 'Add a time window to continue.';
  for (var i = 0; i < windows.length; i++) {
    final w = windows[i];
    if (!w.complete) return 'Choose a start and end time for each window.';
    final name = windows.length == 1 ? 'This window' : 'Window ${i + 1}';
    // v2: plain nudges for the cases Aman named — late night, too early, too short.
    if (w.endMinute! > latest || w.startMinute! >= latest)
      return 'We don’t wash after ${formatWashMinute(latest)}. Choose an end time by ${formatWashMinute(latest)}.';
    if (w.startMinute! < earliest)
      return 'We start at ${formatWashMinute(earliest)}. Choose a start time from ${formatWashMinute(earliest)}.';
    if (w.endMinute! <= w.startMinute!)
      return '$name must end after it starts. Overnight windows aren’t supported.';
    if (w.endMinute! - w.startMinute! < minimumMinutes)
      return '$name is shorter than ${_duration(minimumMinutes)}. Give at least ${_duration(minimumMinutes)} so your Captain has time to reach you and wash.';
    if (notEndedBy != null && w.endMinute! <= notEndedBy)
      return 'Window ${i + 1} has already ended. Choose a later time or another day.';
  }
  final sorted = orderedWashWindows(windows);
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].startMinute! < sorted[i - 1].endMinute!)
      return 'Time windows overlap. Keep them separate or combine them.';
  }
  return null;
}

String _duration(int minutes) => minutes % 60 == 0
    ? '${minutes ~/ 60} ${minutes == 60 ? 'hour' : 'hours'}'
    : '$minutes minutes';

// v2 CU-TIME (12 Nov 2026, Aman): each window is one card with a big, readable time
// range and a slider to drag the start and end (15-minute steps, at least 1 hour apart).
// Tapping a time still opens the clock for an exact minute.
const _sliderStep = 15;

int _ceilTo(int minute, int step) => ((minute + step - 1) ~/ step) * step;

/// The next free 2-hour window after [after] (and after the existing windows), inside
/// service hours; null when the day has no room left.
WashTimeWindow? suggestWashWindow(
  List<WashTimeWindow> windows, {
  int? after,
  int earliest = washDayStartMinute,
  int latest = washDayEndMinute,
}) {
  var start = windows.isEmpty && after == null ? 480 : earliest;
  if (after != null) start = _ceilTo(after + 30, 30);
  for (final w in windows) {
    if (w.complete && w.endMinute! + 60 > start) start = _ceilTo(w.endMinute! + 60, 30);
  }
  if (start < earliest) start = earliest;
  if (start + washMinimumWindowMinutes > latest) return null;
  return WashTimeWindow(startMinute: start, endMinute: (start + 120).clamp(start, latest));
}

class CustomTimeWindowEditor extends StatelessWidget {
  const CustomTimeWindowEditor({
    super.key,
    required this.windows,
    required this.onChanged,
    this.notEndedBy,
    this.earliest = washDayStartMinute,
    this.latest = washDayEndMinute,
  });
  final List<WashTimeWindow> windows;
  final ValueChanged<List<WashTimeWindow>> onChanged;
  final int? notEndedBy;
  final int earliest, latest;

  void _set(int index, WashTimeWindow value) => onChanged([...windows]..[index] = value);

  Future<void> pick(BuildContext context, int index, bool start) async {
    final current = windows[index],
        minute =
            (start ? current.startMinute : current.endMinute) ??
            (start ? 480 : 600);
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Window ${index + 1} · ${start ? 'Start' : 'End'} time',
    );
    if (value == null) return;
    final selected = value.hour * 60 + value.minute;
    // A new start fills a 2-hour end (kept inside service hours), so a window is
    // never left half done. An end the customer already chose is not changed.
    final autoEnd = start && current.endMinute == null
        ? (selected + 120).clamp(selected, latest)
        : null;
    _set(index, WashTimeWindow(
      startMinute: start ? selected : current.startMinute,
      endMinute: start ? (autoEnd ?? current.endMinute) : selected,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final error = validateWashWindows(
      windows,
      notEndedBy: notEndedBy,
      earliest: earliest,
      latest: latest,
    );
    final next = suggestWashWindow(windows, after: notEndedBy, earliest: earliest, latest: latest);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < windows.length; i++) ...[
          _WindowCard(
            key: ValueKey('window-$i-of-${windows.length}'),
            index: i,
            window: windows[i],
            earliest: earliest,
            latest: latest,
            // Today: the slider starts at the next quarter hour, so past times can't be picked.
            floor: notEndedBy == null ? earliest : _ceilTo(notEndedBy!, _sliderStep).clamp(earliest, latest - washMinimumWindowMinutes),
            removable: windows.length > 1,
            onChanged: (w) => _set(i, w),
            onPick: (start) => pick(context, i, start),
            onRemove: () => onChanged([...windows]..removeAt(i)),
          ),
          const Gap(12),
        ],
        if (error != null && windows.isNotEmpty) ...[
          Semantics(liveRegion: true, child: WBanner(tone: Tone.error, icon: WIcon.info, text: error)),
          const Gap(12),
        ],
        WButton(
          windows.isEmpty ? 'Add a time window' : 'Add another window',
          kind: ButtonKind.text,
          icon: WIcon.plus,
          enabled: next != null,
          onTap: () => onChanged([...windows, next!]),
        ),
        const Gap(4),
        const WText(
          'Your Captain comes within one of your windows.',
          WType.caption,
          align: TextAlign.center,
        ),
      ],
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({
    super.key,
    required this.index,
    required this.window,
    required this.earliest,
    required this.latest,
    required this.floor,
    required this.removable,
    required this.onChanged,
    required this.onPick,
    required this.onRemove,
  });
  final int index, earliest, latest, floor;
  final WashTimeWindow window;
  final bool removable;
  final ValueChanged<WashTimeWindow> onChanged;
  final void Function(bool start) onPick;
  final VoidCallback onRemove;

  Widget _time(bool start) {
    final minute = start ? window.startMinute : window.endMinute;
    return Pressable(
      label: 'Window ${index + 1} ${start ? 'start' : 'end'} time${minute == null ? '' : ', ${formatWashMinute(minute)}'}',
      onTap: () => onPick(start),
      child: Column(
        crossAxisAlignment: start ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          WText(start ? 'From' : 'Until', WType.small),
          const Gap(2),
          // The time rolls over as the slider moves.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: child),
            ),
            child: WText(
              minute == null ? 'Choose' : formatWashMinute(minute),
              WType.section,
              key: ValueKey(minute),
              weight: FontWeight.w700,
              color: WColor.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final low = floor.clamp(earliest, latest - washMinimumWindowMinutes).toDouble(), high = latest.toDouble();
    final start = (window.startMinute ?? 480).toDouble().clamp(low, high - washMinimumWindowMinutes);
    final end = (window.endMinute ?? (start + 120)).toDouble().clamp(start + washMinimumWindowMinutes, high);
    final length = window.complete ? window.endMinute! - window.startMinute! : null;
    return WCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: WText('Window ${index + 1}', WType.caption)),
              if (length != null && length > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const ShapeDecoration(color: WColor.primaryTint, shape: StadiumBorder()),
                  child: WText(_span(length), WType.small, color: WColor.primary, weight: FontWeight.w600),
                ),
              if (removable) ...[
                const Gap(4),
                WIconButton(WIcon.trash, size: 40, label: 'Remove window ${index + 1}', onTap: onRemove),
              ],
            ],
          ),
          const Gap(6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _time(true),
              const Expanded(child: Padding(padding: EdgeInsets.only(bottom: 6), child: Center(child: WText('to', WType.caption)))),
              _time(false),
            ],
          ),
          const Gap(4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: WColor.primary,
              inactiveTrackColor: WColor.divider,
              thumbColor: WColor.primary,
              overlayColor: WColor.primary.withValues(alpha: 0.12),
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 12, elevation: 2),
              rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: RangeSlider(
              min: low,
              max: high,
              divisions: ((high - low) / _sliderStep).round().clamp(1, 400),
              values: RangeValues(start, end),
              semanticFormatterCallback: (v) => formatWashMinute(v.round()),
              onChanged: (v) {
                var a = (v.start / _sliderStep).round() * _sliderStep, b = (v.end / _sliderStep).round() * _sliderStep;
                // Keep at least 1 hour: the thumb being dragged pushes the other one.
                if (b - a < washMinimumWindowMinutes) {
                  if (a != window.startMinute) {
                    b = a + washMinimumWindowMinutes;
                    if (b > latest) {
                      b = latest;
                      a = b - washMinimumWindowMinutes;
                    }
                  } else {
                    a = b - washMinimumWindowMinutes;
                    if (a < low) {
                      a = low.round();
                      b = a + washMinimumWindowMinutes;
                    }
                  }
                }
                if (a == window.startMinute && b == window.endMinute) return;
                HapticFeedback.selectionClick();
                onChanged(WashTimeWindow(startMinute: a, endMinute: b));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                WText(formatWashMinute(low.round()), WType.small),
                const Expanded(child: WText('Drag, or tap a time', WType.small, align: TextAlign.center, maxLines: 1)),
                WText(formatWashMinute(latest), WType.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _span(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return [if (h > 0) '$h ${h == 1 ? 'hour' : 'hours'}', if (m > 0) '$m min'].join(' ');
}

class CustomOneTimeScheduleScreen extends StatefulWidget {
  const CustomOneTimeScheduleScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
    this.initialDate,
    this.initialWindows,
    this.earliest = washDayStartMinute,
    this.latest = washDayEndMinute,
    this.footnote,
    this.header,
  });
  final VoidCallback onBack;
  final void Function(DateTime, List<WashTimeWindow>) onContinue;
  final DateTime? initialDate;
  final List<WashTimeWindow>? initialWindows;
  final int earliest, latest;
  /// v2: shown under the editor; null shows nothing (the preview note is the host's call).
  final String? footnote;
  /// v2: the host's booking header (progress bar); null keeps a plain app bar.
  final Widget? header;
  @override
  State<CustomOneTimeScheduleScreen> createState() =>
      _CustomOneTimeScheduleState();
}

class _CustomOneTimeScheduleState extends State<CustomOneTimeScheduleScreen> {
  // v2: late in the evening today can't fit a 1-hour window before closing, so
  // start on tomorrow.
  late DateTime day = widget.initialDate ?? _firstOpenDay();
  DateTime _firstOpenDay() {
    final now = DateTime.now(), today = DateUtils.dateOnly(now);
    // The suggested 8–10 AM window must still fit today, or start on tomorrow.
    final nowMinute = now.hour * 60 + now.minute;
    final noRoomToday = suggestWashWindow(const [], after: nowMinute, earliest: widget.earliest, latest: widget.latest) == null;
    return _todayClosed(now) || noRoomToday ? today.add(const Duration(days: 1)) : today;
  }

  bool _todayClosed(DateTime now) =>
      now.hour * 60 + now.minute + washMinimumWindowMinutes > widget.latest;
  late List<WashTimeWindow> windows =
      widget.initialWindows ?? [_suggested(day)];
  // Until the customer changes a window, the suggestion follows the chosen day
  // (today: the next free 2 hours; other days: 8–10 AM), so it is never already over.
  late bool _touched = widget.initialWindows != null;

  WashTimeWindow _suggested(DateTime d) {
    final now = DateTime.now();
    final later = DateUtils.isSameDay(d, now)
        ? suggestWashWindow(const [], after: now.hour * 60 + now.minute, earliest: widget.earliest, latest: widget.latest)
        : null;
    return later ?? const WashTimeWindow(startMinute: 480, endMinute: 600);
  }

  void _setDay(DateTime d) => setState(() {
    day = d;
    if (!_touched) windows = [_suggested(d)];
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(), today = DateUtils.dateOnly(now);
    final expired = day.isBefore(today);
    final closedToday = DateUtils.isSameDay(day, today) && _todayClosed(now);
    final error = validateWashWindows(
      windows,
      earliest: widget.earliest,
      latest: widget.latest,
      notEndedBy: DateUtils.isSameDay(day, today)
          ? now.hour * 60 + now.minute
          : null,
    );
    return WScreen(
      header: widget.header ?? WAppBar(title: 'Choose time', onLeading: widget.onBack),
      footer: WFooterBar(
        showCall: false,
        child: WButton(
          'Next: check and pay',
          enabled: !expired && !closedToday && error == null,
          onTap: () {
            final current = DateTime.now();
            final invalid =
                day.isBefore(DateUtils.dateOnly(current)) ||
                validateWashWindows(
                      windows,
                      earliest: widget.earliest,
                      latest: widget.latest,
                      notEndedBy: DateUtils.isSameDay(day, current)
                          ? current.hour * 60 + current.minute
                          : null,
                    ) !=
                    null;
            if (invalid) {
              setState(() {});
              return;
            }
            widget.onContinue(day, orderedWashWindows(windows));
          },
        ),
      ),
      children: [
        WTitleBlock(
          'When should we wash it?',
          subtitle: 'Any time from ${formatWashMinute(widget.earliest)} to ${formatWashMinute(widget.latest)}, at least 1 hour.',
        ),
        // 1. The day.
        const WText('Day', WType.title),
        const Gap(10),
        WSegmented(
          options: [
            for (var i = 0; i < 3; i++) Fmt.day(today.add(Duration(days: i))),
          ],
          selection: day.difference(today).inDays,
          onChanged: (i) => _setDay(today.add(Duration(days: i))),
        ),
        const Gap(10),
        Row(
          children: [
            const WIconView(WIcon.calendar, size: 18, color: WColor.secondary),
            const Gap(8),
            Expanded(child: WText(Fmt.date(day), WType.bodyStrong)),
            WLink(
              'Other date',
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: expired ? today : day,
                  firstDate: today,
                  lastDate: DateTime(today.year + 1, today.month, today.day),
                );
                if (d != null) _setDay(d);
              },
            ),
          ],
        ),
        if (expired || closedToday) ...[
          const Gap(12),
          WBanner(
            tone: Tone.error,
            icon: WIcon.info,
            text: expired
                ? 'Choose today or a later date.'
                : 'It’s too late for a wash today. We wash until ${formatWashMinute(widget.latest)}. Choose tomorrow or later.',
          ),
        ],
        const Gap(22),
        // 2. The time.
        const WText('Time', WType.title),
        const Gap(10),
        CustomTimeWindowEditor(
          windows: windows,
          earliest: widget.earliest,
          latest: widget.latest,
          notEndedBy: DateUtils.isSameDay(day, today)
              ? now.hour * 60 + now.minute
              : null,
          onChanged: (value) => setState(() {
            windows = value;
            _touched = true;
          }),
        ),
        if (widget.footnote != null) ...[
          const Gap(16),
          WText(widget.footnote!, WType.caption),
        ],
      ],
    );
  }
}
