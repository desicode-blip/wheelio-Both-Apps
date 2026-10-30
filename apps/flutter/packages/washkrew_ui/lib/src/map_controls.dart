import 'package:flutter/material.dart';

import 'components.dart';
import 'icons.dart';
import 'tokens.dart';

/// "Locate me" on a map: a big white pill with an icon and a word (not the small
/// standard round button), so it is easy to find and to tap. Place it in a corner
/// that keeps the map logo and the centre pin clear.
class MapLocateButton extends StatelessWidget {
  const MapLocateButton({super.key, required this.onTap, this.busy = false, this.label = 'Locate me'});
  final VoidCallback? onTap;
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Pressable(
          onTap: busy ? null : onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: ShapeDecoration(
              color: WColor.white,
              shape: const StadiumBorder(side: BorderSide(color: WColor.border)),
              shadows: [BoxShadow(color: WColor.heading.withValues(alpha: 0.16), blurRadius: 12, offset: const Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Center(child: busy ? const WSpinner(size: 18) : const WIconView(WIcon.locate, size: 18, color: WColor.primary)),
              ),
              const SizedBox(width: 8),
              WText(label, WType.label, weight: semibold, size: 15, color: WColor.heading),
            ]),
          ),
        ),
      );
}
