import 'package:flutter/material.dart';
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
    final next = [...windows], selected = value.hour * 60 + value.minute;
    // v2: a new start fills a 2-hour end (kept inside service hours), so a window is
    // never left half done. An end the customer already chose is not changed.
    final autoEnd = start && current.endMinute == null
        ? (selected + 120).clamp(selected, latest)
        : null;
    next[index] = WashTimeWindow(
      startMinute: start ? selected : current.startMinute,
      endMinute: start ? (autoEnd ?? current.endMinute) : selected,
    );
    onChanged(next);
  }

  Widget field(BuildContext context, int index, bool start) {
    final minute = start
        ? windows[index].startMinute
        : windows[index].endMinute;
    return Expanded(
      child: Pressable(
        label:
            'Window ${index + 1} ${start ? 'start' : 'end'} time${minute == null ? '' : ', ${formatWashMinute(minute)}'}',
        onTap: () => pick(context, index, start),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(12),
          decoration: outlinedDecoration(radius: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WText(start ? 'From' : 'Until', WType.caption),
              const Gap(4),
              WText(
                minute == null ? 'Choose time' : formatWashMinute(minute),
                WType.value,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = validateWashWindows(
      windows,
      notEndedBy: notEndedBy,
      earliest: earliest,
      latest: latest,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < windows.length; i++) ...[
          WCard(
            outlined: true,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: WText('Window ${i + 1}', WType.title)),
                    WIconButton(
                      WIcon.trash,
                      size: 48,
                      label: 'Remove window ${i + 1}',
                      onTap: () => onChanged([...windows]..removeAt(i)),
                    ),
                  ],
                ),
                const Gap(8),
                Row(
                  children: [
                    field(context, i, true),
                    const Gap(12),
                    field(context, i, false),
                  ],
                ),
              ],
            ),
          ),
          const Gap(12),
        ],
        WButton(
          windows.isEmpty ? 'Add a time window' : 'Add another window',
          kind: ButtonKind.outline,
          icon: WIcon.plus,
          onTap: () => onChanged([...windows, const WashTimeWindow()]),
        ),
        if (error != null) ...[
          const Gap(12),
          Semantics(
            liveRegion: true,
            child: WText(
              error,
              WType.caption,
              color: windows.any((w) => !w.complete) || windows.isEmpty
                  ? WColor.secondary
                  : WColor.destructive,
            ),
          ),
        ],
        const Gap(12),
        WText(
          'Any times from ${formatWashMinute(earliest)} to ${formatWashMinute(latest)}, at least ${_duration(washMinimumWindowMinutes)} each. Your Captain comes within one of your windows.',
          WType.caption,
        ),
      ],
    );
  }
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
    final suggestionEnded = widget.initialWindows == null && nowMinute + washMinimumWindowMinutes > 600;
    return _todayClosed(now) || suggestionEnded ? today.add(const Duration(days: 1)) : today;
  }

  bool _todayClosed(DateTime now) =>
      now.hour * 60 + now.minute + washMinimumWindowMinutes > widget.latest;
  late List<WashTimeWindow> windows =
      widget.initialWindows ??
      [const WashTimeWindow(startMinute: 480, endMinute: 600)];
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
        const WTitleBlock(
          'When is your vehicle free?',
          subtitle: 'Add the times that work for you.',
        ),
        WSegmented(
          options: [
            for (var i = 0; i < 3; i++) Fmt.day(today.add(Duration(days: i))),
          ],
          selection: day.difference(today).inDays,
          onChanged: (i) => setState(() => day = today.add(Duration(days: i))),
        ),
        const Gap(12),
        WListRow(
          icon: WIcon.calendar,
          title: Fmt.date(day),
          subtitle: 'Change date',
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: expired ? today : day,
              firstDate: today,
              lastDate: DateTime(today.year + 1, today.month, today.day),
            );
            if (d != null) setState(() => day = d);
          },
        ),
        if (expired || closedToday) ...[
          const Gap(12),
          WText(
            expired
                ? 'Choose today or a later date.'
                : 'It’s too late for a wash today. We wash until ${formatWashMinute(widget.latest)}. Choose tomorrow or later.',
            WType.caption,
            color: WColor.destructive,
          ),
        ],
        const Gap(16),
        CustomTimeWindowEditor(
          windows: windows,
          earliest: widget.earliest,
          latest: widget.latest,
          notEndedBy: DateUtils.isSameDay(day, today)
              ? now.hour * 60 + now.minute
              : null,
          onChanged: (value) => setState(() => windows = value),
        ),
        if (widget.footnote != null) ...[
          const Gap(16),
          WText(widget.footnote!, WType.caption),
        ],
      ],
    );
  }
}
