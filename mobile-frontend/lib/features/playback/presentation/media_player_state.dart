import '../models/playback_metadata.dart';

class MediaPlayerState {
  const MediaPlayerState({
    this.loading = false,
    this.ready = false,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.coveredSeconds = 0,
    this.completed = false,
    this.message,
    this.unavailable = false,
    this.fileMissing = false,
    this.metadata,
  });

  final bool loading;
  final bool ready;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final double coveredSeconds;
  final bool completed;
  final String? message;
  final bool unavailable;
  final bool fileMissing;
  final PlaybackMetadata? metadata;

  int get coveragePercent {
    final totalSec = metadata?.durationSeconds ?? duration.inSeconds;
    if (totalSec <= 0) return completed ? 100 : 0;
    return ((coveredSeconds / totalSec) * 100).clamp(0, 100).round();
  }

  MediaPlayerState copyWith({
    bool? loading,
    bool? ready,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    double? coveredSeconds,
    bool? completed,
    String? message,
    bool clearMessage = false,
    bool? unavailable,
    bool? fileMissing,
    PlaybackMetadata? metadata,
  }) => MediaPlayerState(
    loading: loading ?? this.loading,
    ready: ready ?? this.ready,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    coveredSeconds: coveredSeconds ?? this.coveredSeconds,
    completed: completed ?? this.completed,
    message: clearMessage ? null : (message ?? this.message),
    unavailable: unavailable ?? this.unavailable,
    fileMissing: fileMissing ?? this.fileMissing,
    metadata: metadata ?? this.metadata,
  );
}
