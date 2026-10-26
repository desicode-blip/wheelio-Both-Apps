// Controllers only: existing designed players supply their own controls/layout.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'media_clip.dart';
import 'playback_native.dart'
    if (dart.library.js_interop) 'playback_web.dart'
    as source;

class ClipPlayback extends ChangeNotifier {
  bool ready = false, playing = false, finishedOnce = false, _disposed = false;
  Duration position = Duration.zero, duration = Duration.zero;
  VideoPlayerController? video;
  AudioPlayer? _audio;
  Source? _source;
  Future<void> Function()? _cleanup;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load(MediaClip clip) async {
    final resource = await source.playbackSource(clip);
    _cleanup = resource.cleanup;
    if (_disposed) {
      await resource.cleanup();
      return;
    }
    duration = Duration(seconds: clip.seconds);
    video = resource.video;
    if (video != null) {
      await video!.initialize();
      if (_disposed) return;
      duration = video!.value.duration;
      video!.addListener(() {
        if (_disposed) return;
        position = video!.value.position;
        playing = video!.value.isPlaying;
        if (video!.value.isCompleted) finishedOnce = true;
        _changed();
      });
    } else {
      _audio = AudioPlayer();
      _source = resource.audio;
      _subscriptions.add(
        _audio!.onPositionChanged.listen((p) {
          position = p;
          _changed();
        }),
      );
      _subscriptions.add(
        _audio!.onPlayerComplete.listen((_) {
          playing = false;
          position = duration;
          finishedOnce = true;
          _changed();
        }),
      );
      _subscriptions.add(
        _audio!.onPlayerStateChanged.listen((s) {
          playing = s == PlayerState.playing;
          _changed();
        }),
      );
    }
    ready = true;
    _changed();
  }

  Future<void> toggle() async {
    if (!ready || _disposed) return;
    if (playing) {
      await pause();
      return;
    }
    if (video != null) {
      if (position >= duration) await video!.seekTo(Duration.zero);
      await video!.play();
    } else if (position > Duration.zero && position < duration) {
      await _audio!.resume();
    } else {
      await _audio!.play(_source!);
    }
    playing = true;
    _changed();
  }

  Future<void> pause() async {
    if (video != null) {
      await video!.pause();
    } else {
      await _audio?.pause();
    }
    playing = false;
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      s.cancel();
    }
    () async {
      await video?.dispose();
      await _audio?.dispose();
      await _cleanup?.call();
    }();
    super.dispose();
  }
}

class ClipVideoSurface extends StatelessWidget {
  const ClipVideoSurface(this.player, {super.key});
  final ClipPlayback player;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: player,
    builder: (context, _) => player.ready && player.video != null
        ? VideoPlayer(player.video!)
        : const SizedBox.shrink(),
  );
}
