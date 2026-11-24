import '../models/playback_metadata.dart';

class MediaPlayerState {
  const MediaPlayerState({
    this.loading = false,
    this.ready = false,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
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
  final String? message;
  final bool unavailable;
  final bool fileMissing;
  final PlaybackMetadata? metadata;

  MediaPlayerState copyWith({
    bool? loading,
    bool? ready,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
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
    message: clearMessage ? null : (message ?? this.message),
    unavailable: unavailable ?? this.unavailable,
    fileMissing: fileMissing ?? this.fileMissing,
    metadata: metadata ?? this.metadata,
  );
}
