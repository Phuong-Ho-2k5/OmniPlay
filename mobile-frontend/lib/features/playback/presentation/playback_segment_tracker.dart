import '../models/playback_report.dart';

/// Tracks contiguous actively-played media segments (excluding Pause, Seek, Buffer).
class PlaybackSegmentTracker {
  PlaybackSegmentTracker({
    required this.attemptId,
    required this.durationSeconds,
  });

  final String attemptId;
  final int durationSeconds;

  int _nextEventSeq = 0;
  double? _activeStartSec;
  DateTime? _activePlayedFrom;
  String? _activeVnDayKey;
  final List<PlaybackSegment> _pending = [];

  bool get hasActiveSegment => _activeStartSec != null;
  List<PlaybackSegment> get pendingSegments => List.unmodifiable(_pending);

  /// Records that playback is actively advancing at [positionSeconds] at [nowUtc].
  /// Splits automatically if the Asia/Ho_Chi_Minh (UTC+7) calendar day rolls over.
  void onActivePlaying(double positionSeconds, DateTime nowUtc) {
    final clamped = _clamp(positionSeconds);
    final utc = nowUtc.toUtc();
    final dayKey = _vnDayKey(utc);

    if (_activeStartSec == null) {
      _activeStartSec = clamped;
      _activePlayedFrom = utc;
      _activeVnDayKey = dayKey;
      return;
    }

    if (_activeVnDayKey != dayKey) {
      cutSegment(clamped, utc);
      _activeStartSec = clamped;
      _activePlayedFrom = utc;
      _activeVnDayKey = dayKey;
    }
  }

  /// Closes the current active segment at [endPositionSeconds] and queues it for reporting.
  /// Returns true if a valid non-empty segment was created.
  bool cutSegment(double endPositionSeconds, DateTime nowUtc) {
    final start = _activeStartSec;
    final from = _activePlayedFrom;
    _activeStartSec = null;
    _activePlayedFrom = null;
    _activeVnDayKey = null;

    if (start == null || from == null) return false;
    final end = _clamp(endPositionSeconds);
    final to = nowUtc.toUtc();
    final roundedStart = roundToMillis(start);
    final roundedEnd = roundToMillis(end);
    if (roundedEnd <= roundedStart || !to.isAfter(from)) {
      return false;
    }
    _pending.add(
      PlaybackSegment(
        eventSeq: _nextEventSeq++,
        startSecond: roundedStart,
        endSecond: roundedEnd,
        playedFrom: from,
        playedTo: to,
      ),
    );
    return true;
  }

  /// Removes segments that have been confirmed by the server up to [maxEventSeq].
  void acknowledgeUpTo(int maxEventSeq) {
    _pending.removeWhere((s) => s.eventSeq <= maxEventSeq);
  }

  double _clamp(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return 0;
    if (durationSeconds > 0 && value > durationSeconds) {
      return durationSeconds.toDouble();
    }
    return value;
  }

  // Asia/Ho_Chi_Minh is fixed UTC+7 (no DST).
  String _vnDayKey(DateTime utc) {
    final vn = utc.add(const Duration(hours: 7));
    return '${vn.year}-${vn.month}-${vn.day}';
  }
}
