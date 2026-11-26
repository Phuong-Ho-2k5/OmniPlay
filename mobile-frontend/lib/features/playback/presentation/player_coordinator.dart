import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/data/session_store.dart';
import '../../catalog/data/catalog_repository.dart';
import '../data/listening_session_repository.dart';
import '../data/playback_repository.dart';
import '../models/listening_session.dart';
import '../models/playback_metadata.dart';
import '../models/playback_report.dart';
import 'playback_lifecycle_coordinator.dart';
import 'playback_segment_tracker.dart';

class MusicQueueTrack {
  const MusicQueueTrack({
    required this.mediaId,
    required this.title,
    this.playlistItemId,
  });

  final String mediaId;
  final String title;
  final String? playlistItemId;
}

class AudioSessionSnapshot {
  const AudioSessionSnapshot({
    required this.type,
    this.mediaId,
    this.title,
    this.positionSeconds = 0,
    this.queue = const [],
  });

  final ListeningSessionType type;
  final String? mediaId;
  final String? title;
  final double positionSeconds;
  final List<String> queue;

  bool get hasMedia => mediaId != null;

  AudioSessionSnapshot copyWith({
    String? mediaId,
    bool clearMedia = false,
    String? title,
    double? positionSeconds,
    List<String>? queue,
  }) => AudioSessionSnapshot(
    type: type,
    mediaId: clearMedia ? null : (mediaId ?? this.mediaId),
    title: clearMedia ? null : (title ?? this.title),
    positionSeconds: clearMedia ? 0 : (positionSeconds ?? this.positionSeconds),
    queue: clearMedia ? const [] : (queue ?? this.queue),
  );
}

/// Owns the single shared AudioPlayer for both Music and Podcast sessions (BR-07, BR-08).
class PlayerCoordinator extends ChangeNotifier {
  PlayerCoordinator({
    required this.playbackRepository,
    required this.sessionRepository,
    required this.catalogRepository,
    PlaybackLifecycleCoordinator? lifecycleCoordinator,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc()) {
    _unregisterLifecycle = lifecycleCoordinator?.register(stopAndFlush);
  }

  final PlaybackRepository playbackRepository;
  final ListeningSessionRepository sessionRepository;
  final CatalogRepository catalogRepository;
  final DateTime Function() _now;
  VoidCallback? _unregisterLifecycle;

  static const Duration _reportInterval = Duration(seconds: 15);
  static const Uuid _uuid = Uuid();

  AudioPlayer? _audioPlayer;
  final List<StreamSubscription<Object?>> _subs = [];

  AudioSessionSnapshot _music = const AudioSessionSnapshot(
    type: ListeningSessionType.music,
  );
  AudioSessionSnapshot _podcast = const AudioSessionSnapshot(
    type: ListeningSessionType.podcast,
  );
  ListeningSessionType? _activeType;
  List<MusicQueueTrack> _musicQueue = const [];
  int _musicQueueIndex = -1;
  bool _autoAdvancing = false;

  PlaybackMetadata? _metadata;
  StreamAuthRequest? _activeAuth;
  PlaybackSegmentTracker? _tracker;
  bool _attemptRegistered = false;
  bool _flushing = false;
  double? _queuedResumeSeconds;
  Future<void>? _activeFlush;
  Timer? _reportTimer;

  bool _loading = false;
  bool _ready = false;
  bool _playing = false;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _coveredSeconds = 0;
  bool _completed = false;
  Duration? _resumedFrom;
  String? _errorMessage;
  bool _unavailable = false;
  String? _syncError;

  bool _disposed = false;
  bool _recoveringAuth = false;
  int _sequence = 0;

  ListeningSessionType? get activeType => _activeType;
  AudioSessionSnapshot get musicSession => _music;
  AudioSessionSnapshot get podcastSession => _podcast;
  AudioSessionSnapshot? get activeSession => _activeType == null
      ? null
      : (_activeType == ListeningSessionType.music ? _music : _podcast);

  String? get activeMediaId => activeSession?.mediaId;
  String? get activeTitle => activeSession?.title;
  bool get hasAnySession => _music.hasMedia || _podcast.hasMedia;
  List<MusicQueueTrack> get musicQueue => List.unmodifiable(_musicQueue);
  int get musicQueueIndex => _musicQueueIndex;
  bool get hasMusicQueue =>
      _activeType == ListeningSessionType.music && _musicQueue.length > 1;
  bool get hasPrevious =>
      _activeType == ListeningSessionType.music && _musicQueueIndex > 0;
  bool get hasNext =>
      _activeType == ListeningSessionType.music &&
      _musicQueueIndex >= 0 &&
      _musicQueueIndex + 1 < _musicQueue.length;
  String? get activePlaylistItemId =>
      _activeType == ListeningSessionType.music &&
          _musicQueueIndex >= 0 &&
          _musicQueueIndex < _musicQueue.length
      ? _musicQueue[_musicQueueIndex].playlistItemId
      : null;
  bool get loading => _loading;
  bool get ready => _ready;
  bool get playing => _playing;
  bool get buffering => _buffering;
  Duration get position => _position;
  Duration get duration => _duration;
  double get coveredSeconds => _coveredSeconds;
  bool get completed => _completed;
  Duration? get resumedFrom => _resumedFrom;
  String? get errorMessage => _errorMessage;
  bool get unavailable => _unavailable;
  String? get syncError => _syncError;
  PlaybackMetadata? get metadata => _metadata;

  int get coveragePercent {
    final totalSec = _metadata?.durationSeconds ?? _duration.inSeconds;
    if (totalSec <= 0) return _completed ? 100 : 0;
    return ((_coveredSeconds / totalSec) * 100).clamp(0, 100).round();
  }

  bool isCurrentMedia(String mediaId, ListeningSessionType type) =>
      _activeType == type && activeMediaId == mediaId;

  Future<void> restoreSessions() async {
    if (_disposed) return;
    try {
      final results = await Future.wait([
        sessionRepository.getSession(ListeningSessionType.music),
        sessionRepository.getSession(ListeningSessionType.podcast),
      ]);
      if (_disposed) return;
      _music = await _hydrateSnapshot(results[0]);
      _podcast = await _hydrateSnapshot(results[1]);
      if (_disposed) return;
      if (_activeType == null) {
        if (_music.hasMedia) {
          _activeType = ListeningSessionType.music;
          _position = Duration(
            milliseconds: (_music.positionSeconds * 1000).round(),
          );
          _resumedFrom = _music.positionSeconds > 0 ? _position : null;
        } else if (_podcast.hasMedia) {
          _activeType = ListeningSessionType.podcast;
          _position = Duration(
            milliseconds: (_podcast.positionSeconds * 1000).round(),
          );
          _resumedFrom = _podcast.positionSeconds > 0 ? _position : null;
        }
      }
      _emit();
    } catch (_) {
      // Non-fatal on initial startup; user can still play from Catalog.
    }
  }

  Future<AudioSessionSnapshot> _hydrateSnapshot(
    ListeningSessionState state,
  ) async {
    if (state.currentMediaId == null) {
      return AudioSessionSnapshot(type: state.type);
    }
    String? title;
    try {
      final detail = await catalogRepository.detail(
        id: state.currentMediaId!,
        type: state.type.contentType,
      );
      title = detail.summary.title;
    } catch (_) {
      title = null;
    }
    return AudioSessionSnapshot(
      type: state.type,
      mediaId: state.currentMediaId,
      title: title,
      positionSeconds: state.positionSeconds,
      queue: state.type == ListeningSessionType.music
          ? state.queueMediaIds
          : const [],
    );
  }

  Future<void> openAudio({
    required String mediaId,
    required ListeningSessionType type,
    required String title,
    List<String>? queue,
    double? initialPositionSeconds,
  }) async {
    if (_disposed) return;
    if (_activeType == type &&
        activeMediaId == mediaId &&
        (_ready || _loading)) {
      return;
    }

    // Pause & persist previous audio session before switching.
    if (_activeType != null && activeMediaId != null) {
      await _pauseAndSaveCurrentSession();
      if (_disposed) return;
    }

    final seq = ++_sequence;
    _activeType = type;
    if (type == ListeningSessionType.music) {
      final q = queue ?? [mediaId];
      _musicQueue = [
        for (final id in q)
          MusicQueueTrack(
            mediaId: id,
            title: id == mediaId ? title : 'Bài nhạc',
          ),
      ];
      _musicQueueIndex = _musicQueue.indexWhere((t) => t.mediaId == mediaId);
      if (_musicQueueIndex < 0 && _musicQueue.isNotEmpty) _musicQueueIndex = 0;
    }
    _setSnapshot(
      AudioSessionSnapshot(
        type: type,
        mediaId: mediaId,
        title: title,
        positionSeconds: initialPositionSeconds ?? 0,
        queue: type == ListeningSessionType.music ? (queue ?? [mediaId]) : [],
      ),
    );
    await _loadAudioForActive(
      mediaId: mediaId,
      type: type,
      overridePositionSeconds: initialPositionSeconds,
      seq: seq,
      persistSessionAfterLoad: true,
    );
  }

  /// Plays a playlist queue in order starting at [startIndex].
  Future<void> playMusicQueue({
    required List<MusicQueueTrack> tracks,
    int startIndex = 0,
    bool autoPlay = true,
  }) async {
    if (_disposed || tracks.isEmpty) return;
    final idx = startIndex.clamp(0, tracks.length - 1);
    if (_activeType != null && activeMediaId != null) {
      await _pauseAndSaveCurrentSession();
      if (_disposed) return;
    }

    final seq = ++_sequence;
    _activeType = ListeningSessionType.music;
    _musicQueue = List<MusicQueueTrack>.of(tracks);
    _musicQueueIndex = idx;
    final target = _musicQueue[idx];

    _setSnapshot(
      AudioSessionSnapshot(
        type: ListeningSessionType.music,
        mediaId: target.mediaId,
        title: target.title,
        positionSeconds: 0,
        queue: [for (final t in _musicQueue) t.mediaId],
      ),
    );
    await _loadAudioForActive(
      mediaId: target.mediaId,
      type: ListeningSessionType.music,
      overridePositionSeconds: 0,
      seq: seq,
      persistSessionAfterLoad: true,
    );
    if (_disposed || seq != _sequence || !_ready) return;
    if (autoPlay) {
      unawaited(_ensureAttemptRegistered());
      unawaited(_audioPlayer?.play());
    }
  }

  Future<void> nextTrack({bool autoAdvance = false}) async {
    if (_disposed || !hasNext) return;
    await _moveQueueTo(_musicQueueIndex + 1, autoPlay: _playing || autoAdvance);
  }

  Future<void> previousTrack() async {
    if (_disposed || !hasPrevious) return;
    await _moveQueueTo(_musicQueueIndex - 1, autoPlay: _playing);
  }

  Future<void> _moveQueueTo(int nextIndex, {required bool autoPlay}) async {
    if (_disposed || nextIndex < 0 || nextIndex >= _musicQueue.length) return;
    await _pauseAndSaveCurrentSession();
    if (_disposed) return;

    final seq = ++_sequence;
    _activeType = ListeningSessionType.music;
    _musicQueueIndex = nextIndex;
    final target = _musicQueue[nextIndex];
    _setSnapshot(
      AudioSessionSnapshot(
        type: ListeningSessionType.music,
        mediaId: target.mediaId,
        title: target.title,
        positionSeconds: 0,
        queue: [for (final t in _musicQueue) t.mediaId],
      ),
    );
    await _loadAudioForActive(
      mediaId: target.mediaId,
      type: ListeningSessionType.music,
      overridePositionSeconds: 0,
      seq: seq,
      persistSessionAfterLoad: true,
    );
    if (_disposed || seq != _sequence || !_ready) return;
    if (autoPlay) {
      unawaited(_ensureAttemptRegistered());
      unawaited(_audioPlayer?.play());
    }
  }

  /// Switches between Music and Podcast sessions (BR-07).
  /// Always pauses & saves old session, then restores target session in PAUSED state.
  Future<void> switchSession(ListeningSessionType targetType) async {
    if (_disposed || _activeType == targetType) return;
    if (_activeType != null && activeMediaId != null) {
      await _pauseAndSaveCurrentSession();
      if (_disposed) return;
    }

    final seq = ++_sequence;
    _activeType = targetType;
    _loading = true;
    _ready = false;
    _playing = false;
    _buffering = false;
    _errorMessage = null;
    _unavailable = false;
    _syncError = null;
    _emit();

    await _disposeAudioPlayer();
    if (_disposed || seq != _sequence) return;

    try {
      final remote = await sessionRepository.getSession(targetType);
      if (_disposed || seq != _sequence) return;
      final hydrated = await _hydrateSnapshot(remote);
      if (_disposed || seq != _sequence) return;
      _setSnapshot(hydrated);

      if (hydrated.mediaId == null) {
        _loading = false;
        _ready = false;
        _position = Duration.zero;
        _duration = Duration.zero;
        _resumedFrom = null;
        _emit();
        return;
      }

      await _loadAudioForActive(
        mediaId: hydrated.mediaId!,
        type: targetType,
        overridePositionSeconds: hydrated.positionSeconds,
        seq: seq,
        persistSessionAfterLoad: false,
      );
    } on SessionChangedException {
      return;
    } catch (_) {
      if (_disposed || seq != _sequence) return;
      _loading = false;
      _errorMessage = 'Không thể khôi phục phiên ${targetType.label}.';
      _emit();
    }
  }

  /// Called when Video playback starts so only one audio source plays (BR-08).
  Future<void> notifyVideoStarted() async {
    if (_disposed) return;
    if (_activeType != null && activeMediaId != null && _playing) {
      await _pauseAndSaveCurrentSession();
    }
  }

  Future<void> _loadAudioForActive({
    required String mediaId,
    required ListeningSessionType type,
    double? overridePositionSeconds,
    required int seq,
    required bool persistSessionAfterLoad,
  }) async {
    _stopReportTimer();
    _loading = true;
    _ready = false;
    _playing = false;
    _buffering = false;
    _errorMessage = null;
    _unavailable = false;
    _syncError = null;
    _emit();

    await _disposeAudioPlayer();
    if (_disposed || seq != _sequence) return;

    try {
      final metadata = await playbackRepository.fetchMetadata(mediaId);
      if (_disposed || seq != _sequence) return;

      _metadata = metadata;
      _tracker = PlaybackSegmentTracker(
        attemptId: _uuid.v4(),
        durationSeconds: metadata.durationSeconds,
      );
      _attemptRegistered = false;
      _coveredSeconds = metadata.coveredSeconds;
      _completed = metadata.completed;

      final startSec =
          overridePositionSeconds ?? metadata.resumePositionSeconds;
      final startPos = Duration(milliseconds: (startSec * 1000).round());
      final fallbackDuration = Duration(seconds: metadata.durationSeconds);

      await _openAudioStream(
        metadata: metadata,
        startAt: startPos,
        fallbackDuration: fallbackDuration,
        seq: seq,
        allowAuthRetry: true,
      );

      if (_disposed || seq != _sequence || !_ready) return;
      _resumedFrom = startSec > 0 ? _clamp(startPos, _duration) : null;
      _updateActivePosition(_seconds(_position));
      _emit();

      if (persistSessionAfterLoad) {
        unawaited(_saveSessionToServer(type, includeReport: false));
      }
    } on SessionChangedException {
      return;
    } on ApiException catch (error) {
      if (_disposed || seq != _sequence) return;
      _loading = false;
      _unavailable =
          error.code == 'MEDIA_UNAVAILABLE' ||
          error.code == 'CONTENT_UNAVAILABLE' ||
          error.code == 'MEDIA_FILE_MISSING';
      _errorMessage = _unavailable
          ? 'Nội dung của phiên nghe không còn khả dụng. Vui lòng chọn nội dung khác.'
          : (error.message.isNotEmpty
                ? error.message
                : 'Không thể tải phiên nghe.');
      _emit();
    } catch (_) {
      if (_disposed || seq != _sequence) return;
      _loading = false;
      _errorMessage = 'Không thể khởi tạo trình phát âm thanh.';
      _emit();
    }
  }

  Future<void> _openAudioStream({
    required PlaybackMetadata metadata,
    required Duration startAt,
    required Duration fallbackDuration,
    required int seq,
    required bool allowAuthRetry,
  }) async {
    final request = playbackRepository.buildStreamRequest(metadata.streamPath);
    _activeAuth = request;
    try {
      final player = AudioPlayer();
      _audioPlayer = player;
      final loaded = await player.setAudioSource(
        AudioSource.uri(request.uri, headers: request.headers),
        initialPosition: _clamp(startAt, fallbackDuration),
      );
      if (_disposed || seq != _sequence) {
        await player.dispose();
        return;
      }
      final total = loaded != null && loaded > Duration.zero
          ? loaded
          : fallbackDuration;
      _duration = total;
      _position = _clamp(startAt, total);
      _loading = false;
      _ready = true;
      _playing = false;
      _buffering = false;
      _bindAudioStreams(player, total);
      _emit();
    } catch (error) {
      if (_disposed || seq != _sequence) return;
      if (allowAuthRetry && _looksUnauthorized(error)) {
        final refreshed = await _tryRefreshAuth(request);
        if (_disposed || seq != _sequence) return;
        if (refreshed) {
          await _disposeAudioPlayer();
          await _openAudioStream(
            metadata: metadata,
            startAt: startAt,
            fallbackDuration: fallbackDuration,
            seq: seq,
            allowAuthRetry: false,
          );
          return;
        }
      }
      await _disposeAudioPlayer();
      if (_disposed || seq != _sequence) return;
      _loading = false;
      _ready = false;
      _unavailable = _looksNotFound(error);
      _errorMessage = _unavailable
          ? 'Không tìm thấy tệp âm thanh trên máy chủ.'
          : 'Không thể phát âm thanh. Vui lòng thử lại.';
      _emit();
    }
  }

  void _bindAudioStreams(AudioPlayer player, Duration fallbackDuration) {
    _subs.add(
      player.positionStream.listen((pos) {
        if (_disposed) return;
        if (_playing && !_buffering) {
          _tracker?.onActivePlaying(_seconds(pos), _now());
        }
        _position = pos;
        _updateActivePosition(_seconds(pos));
        _emit();
      }),
    );
    _subs.add(
      player.durationStream.listen((dur) {
        if (_disposed || dur == null || dur <= Duration.zero) return;
        _duration = dur;
        _emit();
      }),
    );
    _subs.add(
      player.playerStateStream.listen(
        (ps) {
          if (_disposed) return;
          final buffering =
              ps.processingState == ProcessingState.loading ||
              ps.processingState == ProcessingState.buffering;
          final completed = ps.processingState == ProcessingState.completed;
          final activelyPlaying = ps.playing && !buffering && !completed;
          final total = _duration > Duration.zero
              ? _duration
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
            if (hasNext && !_autoAdvancing) {
              _autoAdvancing = true;
              unawaited(
                nextTrack(autoAdvance: true).whenComplete(() {
                  _autoAdvancing = false;
                }),
              );
            }
          }

          _ready = true;
          _playing = ps.playing && !completed;
          _buffering = buffering;
          _duration = total;
          _emit();
        },
        onError: (Object error) {
          if (_disposed) return;
          _tracker?.cutSegment(_seconds(_position), _now());
          _stopReportTimer();
          if (!_recoveringAuth &&
              _looksUnauthorized(error) &&
              _activeAuth != null) {
            unawaited(_recoverAuth());
            return;
          }
          _playing = false;
          _buffering = false;
          _errorMessage = 'Lỗi phát âm thanh. Vui lòng thử lại.';
          _emit();
        },
      ),
    );
  }

  Future<void> togglePlayPause() async {
    if (_disposed) return;
    final snap = activeSession;
    if (snap == null || snap.mediaId == null) return;

    // Lazy-load stream if restored from server metadata only.
    if (!_ready && !_loading) {
      final seq = ++_sequence;
      await _loadAudioForActive(
        mediaId: snap.mediaId!,
        type: snap.type,
        overridePositionSeconds: snap.positionSeconds,
        seq: seq,
        persistSessionAfterLoad: false,
      );
      if (_disposed || !_ready) return;
    }

    final player = _audioPlayer;
    if (player == null) return;
    if (_resumedFrom != null) {
      _resumedFrom = null;
      _emit();
    }

    if (player.playing) {
      await _pauseAndSaveCurrentSession();
    } else {
      unawaited(_ensureAttemptRegistered());
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      unawaited(player.play());
    }
  }

  Future<void> seek(Duration target) async {
    if (_disposed || !_ready) return;
    if (_resumedFrom != null) {
      _resumedFrom = null;
    }
    final prevPos = _seconds(_position);
    final wasActive = _playing && !_buffering;
    _tracker?.cutSegment(prevPos, _now());

    final clamped = _clamp(target, _duration);
    await _audioPlayer?.seek(clamped);
    final nextPos = _seconds(clamped);
    _position = clamped;
    _updateActivePosition(nextPos);
    if (wasActive) {
      _tracker?.onActivePlaying(nextPos, _now());
    }
    _emit();
    unawaited(_flushProgress(nextPos));
  }

  Future<void> retryCurrent() async {
    final snap = activeSession;
    if (_disposed || snap == null || snap.mediaId == null) return;
    final seq = ++_sequence;
    await _loadAudioForActive(
      mediaId: snap.mediaId!,
      type: snap.type,
      overridePositionSeconds: snap.positionSeconds,
      seq: seq,
      persistSessionAfterLoad: false,
    );
  }

  Future<void> retrySync() async {
    if (_disposed) return;
    await _flushProgress(_seconds(_position));
  }

  Future<void> _pauseAndSaveCurrentSession() async {
    final type = _activeType;
    if (type == null) return;
    final pos = _seconds(_position);
    _tracker?.cutSegment(pos, _now());
    _stopReportTimer();
    try {
      if (_audioPlayer?.playing ?? false) {
        await _audioPlayer!.pause();
      }
    } catch (_) {
      /* Ignore pause errors. */
    }
    _playing = false;
    _updateActivePosition(pos);
    _emit();
    await _saveSessionToServer(type, includeReport: true);
  }

  Future<void> _saveSessionToServer(
    ListeningSessionType type, {
    required bool includeReport,
  }) async {
    final snap = type == ListeningSessionType.music ? _music : _podcast;
    PlaybackReport? report;
    int? maxSeq;
    final tracker = _tracker;
    if (includeReport &&
        snap.mediaId != null &&
        tracker != null &&
        (_attemptRegistered || tracker.pendingSegments.isNotEmpty)) {
      if (await _ensureAttemptRegistered()) {
        final segments = tracker.pendingSegments;
        if (segments.isNotEmpty) maxSeq = segments.last.eventSeq;
        report = PlaybackReport(
          attemptId: tracker.attemptId,
          resumePositionSeconds: snap.positionSeconds.clamp(
            0.0,
            tracker.durationSeconds.toDouble(),
          ),
          segments: segments,
        );
      }
    }

    try {
      await sessionRepository.saveSession(
        type,
        SaveListeningSessionPayload(
          currentMediaId: snap.mediaId,
          positionSeconds: snap.positionSeconds,
          queue: type == ListeningSessionType.music ? snap.queue : const [],
          playbackReport: report,
        ),
      );
      if (maxSeq != null) {
        tracker?.acknowledgeUpTo(maxSeq);
      }
      if (!_disposed) {
        _syncError = null;
        _emit();
      }
    } catch (_) {
      if (!_disposed) {
        _syncError = 'Chưa lưu được phiên nghe do mất kết nối.';
        _emit();
      }
    }
  }

  Future<void> stopAndFlush({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_disposed) return;
    try {
      await _pauseAndSaveCurrentSession().timeout(timeout);
    } catch (_) {
      /* Best-effort on logout/exit. */
    }
  }

  Future<void> _recoverAuth() async {
    final auth = _activeAuth;
    final meta = _metadata;
    if (_disposed || auth == null || meta == null || _recoveringAuth) return;
    _recoveringAuth = true;
    final resume = _position;
    final wasPlaying = _playing;
    final seq = ++_sequence;
    try {
      final ok = await _tryRefreshAuth(auth);
      if (_disposed || seq != _sequence || !ok) return;
      await _disposeAudioPlayer();
      await _openAudioStream(
        metadata: meta,
        startAt: resume,
        fallbackDuration: Duration(seconds: meta.durationSeconds),
        seq: seq,
        allowAuthRetry: false,
      );
      if (wasPlaying && _ready && !_disposed) {
        unawaited(_audioPlayer?.play());
      }
    } finally {
      _recoveringAuth = false;
    }
  }

  Future<bool> _tryRefreshAuth(StreamAuthRequest request) async {
    try {
      return await playbackRepository.refreshAccessToken(
        generation: request.generation,
        revision: request.revision,
      );
    } catch (_) {
      return false;
    }
  }

  void _startReportTimer() {
    if (_reportTimer != null || _disposed) return;
    _reportTimer = Timer.periodic(_reportInterval, (_) {
      if (_disposed || !_playing || _buffering) return;
      final pos = _seconds(_position);
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
    final mediaId = activeMediaId;
    if (tracker == null || mediaId == null) return false;
    if (_attemptRegistered) return true;
    try {
      await playbackRepository.createAttempt(
        attemptId: tracker.attemptId,
        mediaId: mediaId,
        playlistItemId: activePlaylistItemId,
      );
      _attemptRegistered = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _flushProgress(double resumeSeconds) {
    final tracker = _tracker;
    final mediaId = activeMediaId;
    if (tracker == null || mediaId == null) return Future<void>.value();
    if (_flushing) {
      _queuedResumeSeconds = resumeSeconds;
      return _activeFlush ?? Future<void>.value();
    }
    _flushing = true;
    final future = _drainFlushLoop(tracker, mediaId, resumeSeconds)
        .whenComplete(() {
          _flushing = false;
          _activeFlush = null;
        });
    _activeFlush = future;
    return future;
  }

  Future<void> _drainFlushLoop(
    PlaybackSegmentTracker tracker,
    String mediaId,
    double initialResume,
  ) async {
    double? next = initialResume;
    while (next != null) {
      final resume = next;
      next = null;
      try {
        if (!await _ensureAttemptRegistered()) {
          _markSyncFailed();
          break;
        }
        final segments = tracker.pendingSegments;
        final result = await playbackRepository.reportProgress(
          mediaId: mediaId,
          report: PlaybackReport(
            attemptId: tracker.attemptId,
            resumePositionSeconds: resume.clamp(
              0.0,
              tracker.durationSeconds.toDouble(),
            ),
            segments: segments,
          ),
        );
        if (segments.isNotEmpty) {
          tracker.acknowledgeUpTo(segments.last.eventSeq);
        }
        if (!_disposed) {
          _coveredSeconds = result.coveredSeconds;
          _completed = result.completed;
          _syncError = null;
          _emit();
        }
      } on SessionChangedException {
        break;
      } catch (_) {
        _markSyncFailed();
        break;
      }
      if (_queuedResumeSeconds != null) {
        next = _queuedResumeSeconds;
        _queuedResumeSeconds = null;
      }
    }
  }

  void _markSyncFailed() {
    if (_disposed) return;
    _syncError = 'Chưa đồng bộ được tiến độ do mất kết nối.';
    _emit();
  }

  void _setSnapshot(AudioSessionSnapshot snap) {
    if (snap.type == ListeningSessionType.music) {
      _music = snap;
    } else {
      _podcast = snap;
    }
  }

  void _updateActivePosition(double seconds) {
    final snap = activeSession;
    if (snap == null) return;
    _setSnapshot(snap.copyWith(positionSeconds: seconds));
  }

  double _seconds(Duration d) => d.inMilliseconds / 1000.0;

  Duration _clamp(Duration value, Duration max) {
    if (value < Duration.zero) return Duration.zero;
    if (max > Duration.zero && value > max) return max;
    return value;
  }

  bool _looksUnauthorized(Object error) {
    final t = error.toString();
    return t.contains('401') || t.contains('Unauthorized');
  }

  bool _looksNotFound(Object error) {
    final t = error.toString();
    return t.contains('404') || t.contains('MEDIA_FILE_MISSING');
  }

  Future<void> _disposeAudioPlayer() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final p = _audioPlayer;
    _audioPlayer = null;
    if (p != null) {
      await p.dispose();
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _unregisterLifecycle?.call();
    _unregisterLifecycle = null;
    _stopReportTimer();
    _disposed = true;
    _sequence++;
    unawaited(_disposeAudioPlayer());
    super.dispose();
  }
}
