import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/data/session_store.dart';
import '../../catalog/models/content_type.dart';
import '../data/playback_repository.dart';
import '../models/playback_metadata.dart';
import '../models/playback_report.dart';
import 'media_player_state.dart';
import 'playback_segment_tracker.dart';

class MediaPlayerViewModel extends ChangeNotifier {
  MediaPlayerViewModel({
    required this.repository,
    required this.mediaId,
    required this.type,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final PlaybackRepository repository;
  final String mediaId;
  final ContentType type;
  final DateTime Function() _now;

  static const Duration _reportInterval = Duration(seconds: 15);
  static const Uuid _uuid = Uuid();

  MediaPlayerState _state = const MediaPlayerState();
  MediaPlayerState get state => _state;

  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  AudioPlayer? _audioPlayer;
  final List<StreamSubscription<Object?>> _audioSubs = [];

  StreamAuthRequest? _activeAuth;
  PlaybackSegmentTracker? _tracker;
  bool _attemptRegistered = false;
  bool _flushing = false;
  bool _videoEndReported = false;
  Timer? _reportTimer;

  bool _disposed = false;
  bool _recoveringAuth = false;
  int _sequence = 0;

  Future<void> load({Duration? startAt, bool autoPlay = false}) async {
    if (_disposed || type == ContentType.post) return;
    final seq = ++_sequence;
    _stopReportTimer();
    _setState(
      _state.copyWith(
        loading: true,
        ready: false,
        playing: false,
        buffering: false,
        clearMessage: true,
        unavailable: false,
        fileMissing: false,
      ),
    );
    await _disposePlayers();
    if (_disposed || seq != _sequence) return;

    try {
      final metadata = await repository.fetchMetadata(mediaId);
      if (_disposed || seq != _sequence) return;
      _tracker ??= PlaybackSegmentTracker(
        attemptId: _uuid.v4(),
        durationSeconds: metadata.durationSeconds,
      );
      final resume =
          startAt ??
          Duration(
            milliseconds: (metadata.resumePositionSeconds * 1000).round(),
          );
      await _openStream(
        metadata: metadata,
        startAt: resume,
        autoPlay: autoPlay,
        seq: seq,
        allowAuthRetry: true,
      );
    } on SessionChangedException {
      return;
    } on ApiException catch (error) {
      if (_disposed || seq != _sequence) return;
      _handleApiError(error);
    } catch (_) {
      if (_disposed || seq != _sequence) return;
      _setState(
        _state.copyWith(
          loading: false,
          ready: false,
          message: 'Không thể khởi tạo trình phát media. Vui lòng thử lại.',
        ),
      );
    }
  }

  Future<void> _openStream({
    required PlaybackMetadata metadata,
    required Duration startAt,
    required bool autoPlay,
    required int seq,
    required bool allowAuthRetry,
  }) async {
    final request = repository.buildStreamRequest(metadata.streamPath);
    _activeAuth = request;
    final fallbackDuration = Duration(seconds: metadata.durationSeconds);

    try {
      if (type == ContentType.video) {
        final controller = VideoPlayerController.networkUrl(
          request.uri,
          httpHeaders: request.headers,
        );
        _videoController = controller;
        await controller.initialize();
        if (_disposed || seq != _sequence) {
          await controller.dispose();
          return;
        }
        final total = controller.value.duration > Duration.zero
            ? controller.value.duration
            : fallbackDuration;
        final clamped = _clamp(startAt, total);
        if (clamped > Duration.zero) {
          await controller.seekTo(clamped);
        }
        _videoEndReported = false;
        controller.addListener(_onVideoTick);
        _setState(
          MediaPlayerState(
            loading: false,
            ready: true,
            playing: false,
            buffering: controller.value.isBuffering,
            position: clamped,
            duration: total,
            coveredSeconds: _state.coveredSeconds,
            completed: metadata.completed || _state.completed,
            metadata: metadata,
          ),
        );
        if (autoPlay) {
          unawaited(_ensureAttemptRegistered());
          await controller.play();
        }
      } else {
        final player = AudioPlayer();
        _audioPlayer = player;
        final loadedDuration = await player.setAudioSource(
          AudioSource.uri(request.uri, headers: request.headers),
          initialPosition: _clamp(startAt, fallbackDuration),
        );
        if (_disposed || seq != _sequence) {
          await player.dispose();
          return;
        }
        final total = loadedDuration != null && loadedDuration > Duration.zero
            ? loadedDuration
            : fallbackDuration;
        _bindAudioStreams(player, total, metadata);
        _setState(
          MediaPlayerState(
            loading: false,
            ready: true,
            playing: player.playing,
            buffering: false,
            position: _clamp(startAt, total),
            duration: total,
            coveredSeconds: _state.coveredSeconds,
            completed: metadata.completed || _state.completed,
            metadata: metadata,
          ),
        );
        if (autoPlay) {
          unawaited(_ensureAttemptRegistered());
          unawaited(player.play());
        }
      }
    } catch (error) {
      if (_disposed || seq != _sequence) return;
      if (allowAuthRetry && _looksUnauthorized(error)) {
        final refreshed = await _tryRefreshAuth(request);
        if (_disposed || seq != _sequence) return;
        if (refreshed) {
          await _disposePlayers();
          await _openStream(
            metadata: metadata,
            startAt: startAt,
            autoPlay: autoPlay,
            seq: seq,
            allowAuthRetry: false,
          );
          return;
        }
      }
      await _disposePlayers();
      if (_disposed || seq != _sequence) return;
      _handleStreamError(error);
    }
  }

  void _onVideoTick() {
    final controller = _videoController;
    if (_disposed || controller == null) return;
    final value = controller.value;
    if (value.hasError) {
      _tracker?.cutSegment(_seconds(_state.position), _now());
      _stopReportTimer();
      final desc = value.errorDescription ?? '';
      if (!_recoveringAuth && _looksUnauthorized(desc) && _activeAuth != null) {
        unawaited(_recoverFromPlaybackAuthError());
        return;
      }
      _setState(
        _state.copyWith(
          loading: false,
          playing: false,
          buffering: false,
          message: _looksNotFound(desc)
              ? 'Không tìm thấy tệp media trên máy chủ.'
              : 'Không thể phát video. Vui lòng kiểm tra kết nối và thử lại.',
          fileMissing: _looksNotFound(desc),
        ),
      );
      return;
    }

    final total = value.duration > Duration.zero
        ? value.duration
        : _state.duration;
    final ended =
        total > Duration.zero &&
        !value.isPlaying &&
        value.position >= total - const Duration(milliseconds: 200);

    if (value.isPlaying && !value.isBuffering) {
      _videoEndReported = false;
      _tracker?.onActivePlaying(_seconds(value.position), _now());
      _startReportTimer();
    } else if (value.isBuffering) {
      _tracker?.cutSegment(_seconds(value.position), _now());
    } else if (ended && !_videoEndReported) {
      _videoEndReported = true;
      _tracker?.cutSegment(_seconds(total), _now());
      _stopReportTimer();
      unawaited(_flushProgress(_seconds(total)));
    }

    _setState(
      _state.copyWith(
        ready: value.isInitialized,
        playing: value.isPlaying,
        buffering: value.isBuffering,
        position: value.position,
        duration: total,
      ),
    );
  }

  void _bindAudioStreams(
    AudioPlayer player,
    Duration fallbackDuration,
    PlaybackMetadata metadata,
  ) {
    _audioSubs.add(
      player.positionStream.listen((pos) {
        if (_disposed) return;
        if (_state.playing && !_state.buffering) {
          _tracker?.onActivePlaying(_seconds(pos), _now());
        }
        _setState(_state.copyWith(position: pos));
      }),
    );
    _audioSubs.add(
      player.durationStream.listen((dur) {
        if (_disposed || dur == null || dur <= Duration.zero) return;
        _setState(_state.copyWith(duration: dur));
      }),
    );
    _audioSubs.add(
      player.playerStateStream.listen(
        (ps) {
          if (_disposed) return;
          final buffering =
              ps.processingState == ProcessingState.loading ||
              ps.processingState == ProcessingState.buffering;
          final completed = ps.processingState == ProcessingState.completed;
          final activelyPlaying = ps.playing && !buffering && !completed;
          final total = _state.duration > Duration.zero
              ? _state.duration
              : fallbackDuration;

          if (activelyPlaying) {
            _tracker?.onActivePlaying(_seconds(player.position), _now());
            _startReportTimer();
          } else if (buffering) {
            _tracker?.cutSegment(_seconds(player.position), _now());
          } else if (completed) {
            _tracker?.cutSegment(_seconds(total), _now());
            _stopReportTimer();
            unawaited(_flushProgress(_seconds(total)));
          }

          _setState(
            _state.copyWith(
              ready: true,
              playing: ps.playing && !completed,
              buffering: buffering,
              duration: total,
              metadata: metadata,
            ),
          );
        },
        onError: (Object error) {
          if (_disposed) return;
          _tracker?.cutSegment(_seconds(_state.position), _now());
          _stopReportTimer();
          if (!_recoveringAuth &&
              _looksUnauthorized(error) &&
              _activeAuth != null) {
            unawaited(_recoverFromPlaybackAuthError());
            return;
          }
          _handleStreamError(error);
        },
      ),
    );
  }

  Future<void> _recoverFromPlaybackAuthError() async {
    final auth = _activeAuth;
    final metadata = _state.metadata;
    if (_disposed || auth == null || metadata == null || _recoveringAuth) {
      return;
    }
    _recoveringAuth = true;
    final resumePos = _state.position;
    final wasPlaying = _state.playing;
    final seq = ++_sequence;
    try {
      final refreshed = await _tryRefreshAuth(auth);
      if (_disposed || seq != _sequence) return;
      if (refreshed) {
        await _disposePlayers();
        await _openStream(
          metadata: metadata,
          startAt: resumePos,
          autoPlay: wasPlaying,
          seq: seq,
          allowAuthRetry: false,
        );
      }
    } finally {
      _recoveringAuth = false;
    }
  }

  Future<bool> _tryRefreshAuth(StreamAuthRequest request) async {
    try {
      return await repository.refreshAccessToken(
        generation: request.generation,
        revision: request.revision,
      );
    } on SessionChangedException {
      return false;
    } on ApiException {
      return false;
    }
  }

  Future<void> togglePlayPause() async {
    if (_disposed || !_state.ready) return;
    if (type == ContentType.video) {
      final c = _videoController;
      if (c == null) return;
      if (c.value.isPlaying) {
        final pos = _seconds(c.value.position);
        _tracker?.cutSegment(pos, _now());
        _stopReportTimer();
        await c.pause();
        unawaited(_flushProgress(pos));
      } else {
        unawaited(_ensureAttemptRegistered());
        if (c.value.duration > Duration.zero &&
            c.value.position >= c.value.duration) {
          await c.seekTo(Duration.zero);
        }
        await c.play();
      }
    } else {
      final p = _audioPlayer;
      if (p == null) return;
      if (p.playing) {
        final pos = _seconds(p.position);
        _tracker?.cutSegment(pos, _now());
        _stopReportTimer();
        await p.pause();
        unawaited(_flushProgress(pos));
      } else {
        unawaited(_ensureAttemptRegistered());
        if (p.processingState == ProcessingState.completed) {
          await p.seek(Duration.zero);
        }
        unawaited(p.play());
      }
    }
  }

  Future<void> seek(Duration target) async {
    if (_disposed || !_state.ready) return;
    final previousPos = _seconds(_state.position);
    final wasActive = _state.playing && !_state.buffering;
    _tracker?.cutSegment(previousPos, _now());

    final clamped = _clamp(target, _state.duration);
    if (type == ContentType.video) {
      await _videoController?.seekTo(clamped);
    } else {
      await _audioPlayer?.seek(clamped);
    }

    final nextPos = _seconds(clamped);
    if (wasActive) {
      _tracker?.onActivePlaying(nextPos, _now());
    }
    unawaited(_flushProgress(nextPos));
  }

  Future<void> retry() => load(startAt: _state.position, autoPlay: false);

  void _startReportTimer() {
    if (_reportTimer != null || _disposed) return;
    _reportTimer = Timer.periodic(_reportInterval, (_) {
      if (_disposed || !_state.playing || _state.buffering) return;
      final pos = _seconds(_state.position);
      final nowUtc = _now();
      _tracker?.cutSegment(pos, nowUtc);
      _tracker?.onActivePlaying(pos, nowUtc);
      unawaited(_flushProgress(pos));
    });
  }

  void _stopReportTimer() {
    _reportTimer?.cancel();
    _reportTimer = null;
  }

  Future<bool> _ensureAttemptRegistered() async {
    final tracker = _tracker;
    if (tracker == null) return false;
    if (_attemptRegistered) return true;
    try {
      await repository.createAttempt(
        attemptId: tracker.attemptId,
        mediaId: mediaId,
      );
      _attemptRegistered = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _flushProgress(double resumeSeconds) async {
    final tracker = _tracker;
    if (tracker == null || _flushing) return;
    _flushing = true;
    try {
      if (!await _ensureAttemptRegistered()) return;
      final segments = tracker.pendingSegments;
      final clampedResume = resumeSeconds.clamp(
        0.0,
        tracker.durationSeconds.toDouble(),
      );
      final result = await repository.reportProgress(
        mediaId: mediaId,
        report: PlaybackReport(
          attemptId: tracker.attemptId,
          resumePositionSeconds: clampedResume,
          segments: segments,
        ),
      );
      if (segments.isNotEmpty) {
        tracker.acknowledgeUpTo(segments.last.eventSeq);
      }
      if (!_disposed) {
        _setState(
          _state.copyWith(
            coveredSeconds: result.coveredSeconds,
            completed: result.completed,
          ),
        );
      }
    } catch (_) {
      // Unacknowledged segments remain queued with original eventSeq for retry.
    } finally {
      _flushing = false;
    }
  }

  double _seconds(Duration d) => d.inMilliseconds / 1000.0;

  void _handleApiError(ApiException error) {
    final unavailable =
        error.code == 'MEDIA_UNAVAILABLE' ||
        error.code == 'CONTENT_UNAVAILABLE';
    final fileMissing = error.code == 'MEDIA_FILE_MISSING';
    _setState(
      _state.copyWith(
        loading: false,
        ready: false,
        unavailable: unavailable,
        fileMissing: fileMissing,
        message: unavailable
            ? 'Nội dung media không tồn tại hoặc đã ngừng phục vụ.'
            : fileMissing
            ? 'Không tìm thấy tệp media trên máy chủ.'
            : error.message.isNotEmpty
            ? error.message
            : 'Không thể kết nối máy chủ phát media.',
      ),
    );
  }

  void _handleStreamError(Object error) {
    final missing = _looksNotFound(error);
    _setState(
      _state.copyWith(
        loading: false,
        ready: false,
        playing: false,
        buffering: false,
        fileMissing: missing,
        message: missing
            ? 'Không tìm thấy tệp media trên máy chủ.'
            : 'Không thể phát media. Vui lòng kiểm tra kết nối và thử lại.',
      ),
    );
  }

  bool _looksUnauthorized(Object error) {
    final text = error.toString();
    return text.contains('401') || text.contains('Unauthorized');
  }

  bool _looksNotFound(Object error) {
    final text = error.toString();
    return text.contains('404') || text.contains('MEDIA_FILE_MISSING');
  }

  Duration _clamp(Duration value, Duration max) {
    if (value < Duration.zero) return Duration.zero;
    if (max > Duration.zero && value > max) return max;
    return value;
  }

  Future<void> _disposePlayers() async {
    for (final sub in _audioSubs) {
      await sub.cancel();
    }
    _audioSubs.clear();
    final audio = _audioPlayer;
    _audioPlayer = null;
    if (audio != null) {
      await audio.dispose();
    }
    final video = _videoController;
    _videoController = null;
    if (video != null) {
      video.removeListener(_onVideoTick);
      await video.dispose();
    }
  }

  void _setState(MediaPlayerState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    final finalPos = _seconds(_state.position);
    _tracker?.cutSegment(finalPos, _now());
    _stopReportTimer();
    if (_attemptRegistered || (_tracker?.pendingSegments.isNotEmpty ?? false)) {
      unawaited(_flushProgress(finalPos));
    }
    _disposed = true;
    _sequence++;
    unawaited(_disposePlayers());
    super.dispose();
  }
}
