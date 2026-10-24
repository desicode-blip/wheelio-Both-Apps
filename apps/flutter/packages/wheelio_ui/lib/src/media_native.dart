import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'media_clip.dart';
import 'device.dart';

Future<File> _temporary(String suffix) async {
  final dir = await getTemporaryDirectory();
  return File(
    '${dir.path}/wheelio-${DateTime.now().microsecondsSinceEpoch}.$suffix',
  );
}

void _validate(MediaClip clip) {
  if (clip.bytes.isEmpty ||
      clip.bytes.length > 20 * 1024 * 1024 ||
      clip.seconds < 1 ||
      clip.seconds > 30) {
    throw const MediaAccessException(
      'Record a clip of up to 30 seconds and 20 MB.',
    );
  }
}

Future<MediaClip?> captureVideo(BuildContext context) async {
  try {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    if (file == null) return null;
    if(await file.length()>20*1024*1024){await File(file.path).delete();throw const MediaAccessException('Record a shorter video, smaller than 20 MB.');}
    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
      final clip = MediaClip(
        bytes: await file.readAsBytes(),
        contentType: file.path.toLowerCase().endsWith('.mov')
            ? 'video/quicktime'
            : 'video/mp4',
        seconds: controller.value.duration.inSeconds.clamp(1, 31),
      );
      _validate(clip);
      return clip;
    } finally {
      await controller.dispose();
      await File(file.path).delete().catchError((_) => File(file.path));
    }
  } on MediaAccessException {
    rethrow;
  } catch (_) {
    throw const MediaAccessException(
      'Camera or microphone could not open. Allow access in Settings and try again.',
      settings: true,
    );
  }
}

Future<MediaClip?> captureVoice(BuildContext context) => showDialog<MediaClip>(
  context: context,
  builder: (_) => const _VoiceDialog(),
);

class _VoiceDialog extends StatefulWidget {
  const _VoiceDialog();
  @override
  State<_VoiceDialog> createState() => _VoiceDialogState();
}

class _VoiceDialogState extends State<_VoiceDialog> {
  final recorder = AudioRecorder();
  final elapsed = Stopwatch();
  Timer? limit;
  File? file;
  bool recording = false, busy = false;
  String? error;
  Future<void> start() async {
    setState(() => busy = true);
    try {
      if (!await recorder.hasPermission()) {
        throw const MediaAccessException(
          'Allow Microphone access in Settings.',
          settings: true,
        );
      }
      if (!mounted) return;
      file = await _temporary('m4a');
      if (!mounted) return;
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
        ),
        path: file!.path,
      );
      if (!mounted) {
        await recorder.cancel();
        return;
      }
      elapsed.start();
      setState(() => recording = true);
      limit = Timer(const Duration(seconds: 30), stop);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is MediaAccessException
              ? e.message
              : 'Recording could not start. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> stop() async {
    if (busy || !recording) return;
    limit?.cancel();
    elapsed.stop();
    setState(() => busy = true);
    try {
      await recorder.stop();
      final clip = MediaClip(
        bytes: await file!.readAsBytes(),
        contentType: 'audio/mp4',
        seconds: elapsed.elapsed.inSeconds.clamp(1, 30),
      );
      _validate(clip);
      if (mounted) Navigator.pop(context, clip);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Recording could not be saved. Close and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    limit?.cancel();
    recorder.dispose();
    file?.delete().catchError((_) => file!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(recording ? 'Recording voice note' : 'Voice note'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Up to 30 seconds. Tap Stop to save. Nothing is recorded before you tap Start.',
        ),
        if (error != null) Text(error!),
        if (error != null)
          TextButton(
            onPressed: Device.openSettings,
            child: const Text('Open Settings'),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : recording
            ? stop
            : start,
        child: Text(recording ? 'Stop and save' : 'Start recording'),
      ),
    ],
  );
}

class MediaPreview extends StatefulWidget {
  const MediaPreview(this.clip, {super.key});
  final MediaClip clip;
  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  File? file;
  VideoPlayerController? video;
  AudioPlayer? audio;
  StreamSubscription<void>? completion;
  bool ready = false, playing = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      file = await _temporary(widget.clip.video ? 'mp4' : 'm4a');
      await file!.writeAsBytes(widget.clip.bytes, flush: true);
      if (!mounted) {
        await file!.delete();
        return;
      }
      if (widget.clip.video) {
        video = VideoPlayerController.file(file!);
        await video!.initialize();
      } else {
        audio = AudioPlayer();
        completion = audio!.onPlayerComplete.listen((_) {
          if (mounted) setState(() => playing = false);
        });
      }
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Clip could not play. Record it again.');
      }
    }
  }

  @override
  void dispose() {
    completion?.cancel();
    video?.dispose();
    audio?.dispose();
    file?.delete().catchError((_) => file!);
    super.dispose();
  }

  Future<void> toggle() async {
    try {
      if (widget.clip.video) {
        if (video!.value.position >= video!.value.duration) {
          await video!.seekTo(Duration.zero);
        }
        if (video!.value.isPlaying) {
          await video!.pause();
        } else {
          await video!.play();
        }
      } else if (playing) {
        await audio!.pause();
      } else {
        await audio!.play(DeviceFileSource(file!.path));
      }
      if (mounted) {
        setState(
          () => playing = widget.clip.video ? video!.value.isPlaying : !playing,
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Playback failed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (error != null) Text(error!),
      if (ready && video != null)
        AspectRatio(
          aspectRatio: video!.value.aspectRatio,
          child: VideoPlayer(video!),
        ),
      FilledButton.icon(
        onPressed: ready ? toggle : null,
        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        label: Text(
          '${playing ? 'Pause' : 'Play'} ${widget.clip.video ? 'video' : 'voice note'} · ${widget.clip.seconds}s',
        ),
      ),
    ],
  );
}
