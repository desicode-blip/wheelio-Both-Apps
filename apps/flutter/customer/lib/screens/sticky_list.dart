import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 CU-VEHICLE (5 Nov 2026, Aman): the "Add new vehicle" action sits right
// under the list. When the list grows taller than the screen, the action stays
// stuck at the bottom and the list scrolls under it, so it is never out of sight.

class StickyActionList extends StatelessWidget {
  const StickyActionList({super.key, this.header = const [], required this.items, required this.action, this.bottom = 24});
  final List<Widget> header;
  final List<Widget> items;
  final Widget action;
  final double bottom;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ...header,
      // Shrinks to its content when short; fills the space and scrolls when long.
      Flexible(child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: items)),
      const SizedBox(height: 4),
      action,
      SizedBox(height: bottom),
    ],
  );
}

/// The dashed "+ Add new vehicle" button.
class AddVehicleButton extends StatelessWidget {
  const AddVehicleButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: const DashedBorder(
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WIconView(WIcon.plus, size: 16, color: WColor.primaryStrong, weight: semibold),
            SizedBox(width: 10),
            WText('Add new vehicle', WType.title, color: WColor.primaryStrong),
          ],
        ),
      ),
    ),
  );
}
