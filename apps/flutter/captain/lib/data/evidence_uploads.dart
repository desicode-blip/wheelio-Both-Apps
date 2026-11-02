import 'dart:async';
import 'dart:typed_data';

enum EvidenceSendState { uploading, done, failed }

class EvidenceUpload {
  EvidenceUpload(this.bytes, this.send);
  final Uint8List bytes;
  final Future<void> Function() send;
  EvidenceSendState state = EvidenceSendState.uploading;
  Object? error;
  Future<void>? pending;
}

/// Captures advance locally; progression still waits for real server evidence.
class EvidenceUploads {
  EvidenceUploads(this.changed);
  final void Function() changed;
  final Map<String, EvidenceUpload> entries = {};

  void add(String key, Uint8List bytes, Future<void> Function() send) {
    if (entries[key]?.pending != null) throw StateError('This photo is still sending.');
    final entry = EvidenceUpload(bytes, send);
    entries[key] = entry;
    _start(key, entry);
  }

  void _start(String key, EvidenceUpload entry) {
    entry.state = EvidenceSendState.uploading;
    entry.error = null;
    final task = Future<void>.sync(entry.send).then((_) {
      entry.state = EvidenceSendState.done;
    }, onError: (Object error) {
      entry.state = EvidenceSendState.failed;
      entry.error = error;
    });
    entry.pending = task;
    unawaited(task.whenComplete(() {
      entry.pending = null;
      if (identical(entries[key], entry)) changed();
    }));
    changed();
  }

  Future<void> retry(String key) async {
    final entry = entries[key];
    if (entry == null) return;
    if (entry.state == EvidenceSendState.failed) _start(key, entry);
    await entry.pending;
    if (entry.error != null) throw entry.error!;
  }

  Future<void> flush(Iterable<String> keys) async {
    await Future.wait(keys.map(retry));
  }

  void clear() => entries.clear();
}
