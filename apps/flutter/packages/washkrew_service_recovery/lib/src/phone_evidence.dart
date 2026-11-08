import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 (8 Nov): on iPhone/Android the handoff's browser video frame is replaced with the
// app's own camera (captureVideo) and player. Preview only: the clip stays in this
// app's memory; private upload and the owner's copy need Ajay's evidence storage.

class PreviewEvidence {
  static MediaClip? clip;
}

class PhoneEvidence extends StatefulWidget {
  const PhoneEvidence({super.key, required this.capture});

  /// true: the Captain records (or retakes); false: watch the recorded video.
  final bool capture;
  @override
  State<PhoneEvidence> createState() => _PhoneEvidenceState();
}

class _PhoneEvidenceState extends State<PhoneEvidence> {
  ClipPlayback? player;
  String? error;
  bool recording = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final clip = PreviewEvidence.clip;
    player?.dispose();
    player = null;
    if (clip == null) return;
    final p = ClipPlayback();
    setState(() => player = p);
    try {
      await p.load(clip);
    } catch (_) {
      if (mounted) setState(() => error = 'This video can’t play here.');
    }
  }

  Future<void> _record() async {
    setState(() {
      recording = true;
      error = null;
    });
    try {
      final clip = await captureVideo(context);
      if (clip != null) {
        PreviewEvidence.clip = clip;
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => error = e is MediaAccessException ? e.message : 'The camera didn’t open. Try again.');
    } finally {
      if (mounted) setState(() => recording = false);
    }
  }

  @override
  void dispose() {
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = player;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF111111)),
                  ClipVideoSurface(p),
                  Center(
                    child: ListenableBuilder(
                      listenable: p,
                      builder: (context, _) => WIconButton(
                        p.playing ? WIcon.pause : WIcon.play,
                        size: 56,
                        label: p.playing ? 'Pause video' : 'Play video',
                        onTap: p.ready ? p.toggle : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          WCard(
            outlined: true,
            child: WText(
              widget.capture ? 'Record the spot and its surroundings. Avoid faces and documents.' : 'The Captain’s video plays here once video upload is connected.',
              WType.body,
            ),
          ),
        if (widget.capture) ...[
          const Gap(12),
          WButton(
            recording ? 'Opening camera…' : p == null ? 'Record video' : 'Retake video',
            kind: p == null ? ButtonKind.primary : ButtonKind.outline,
            icon: WIcon.camera,
            enabled: !recording,
            onTap: _record,
          ),
        ],
        if (error != null) ...[
          const Gap(8),
          WText(error!, WType.caption, color: WColor.destructive),
        ],
      ],
    );
  }
}
