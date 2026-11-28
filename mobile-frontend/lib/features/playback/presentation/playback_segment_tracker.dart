import '../models/playback_report.dart';

class PlaybackSegmentBatch {
  PlaybackSegmentBatch({
    required this.questSetId,
    required List<PlaybackSegment> segments,
  }) : segments = List.unmodifiable(segments);

  final String? questSetId;
  final List<PlaybackSegment> segments;
}

class _TaggedSegment {
  const _TaggedSegment(this.questSetId, this.segment);
  final String? questSetId;
  final PlaybackSegment segment;
}

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
  String? _activeQuestSetId;
  final List<_TaggedSegment> _pending = [];

  bool get hasActiveSegment => _activeStartSec != null;
  List<PlaybackSegment> get pendingSegments =>
      List.unmodifiable([for (final entry in _pending) entry.segment]);

  /// Groups pending segments into contiguous batches sharing the same [questSetId].
  List<PlaybackSegmentBatch> pendingBatches() {
    if (_pending.isEmpty) return const [];
    final batches = <PlaybackSegmentBatch>[];
    String? currentQuestSetId = _pending.first.questSetId;
    var currentSegments = <PlaybackSegment>[];
    for (final entry in _pending) {
      if (entry.questSetId != currentQuestSetId) {
        batches.add(
          PlaybackSegmentBatch(
            questSetId: currentQuestSetId,
            segments: currentSegments,
          ),
        );
        currentQuestSetId = entry.questSetId;
        currentSegments = <PlaybackSegment>[];
      }
      currentSegments.add(entry.segment);
    }
    if (currentSegments.isNotEmpty) {
      batches.add(
        PlaybackSegmentBatch(
          questSetId: currentQuestSetId,
          segments: currentSegments,
        ),
      );
    }
    return batches;
  }

  /// Records that playback is actively advancing at [positionSeconds] at [nowUtc].
  /// Splits automatically if the Asia/Ho_Chi_Minh (UTC+7) calendar day rolls over
  /// or when [questSetId] changes.
  void onActivePlaying(
    double positionSeconds,
    DateTime nowUtc, {
    String? questSetId,
  }) {
    final clamped = _clamp(positionSeconds);
    final utc = nowUtc.toUtc();
    final dayKey = _vnDayKey(utc);

    if (_activeStartSec == null) {
      _activeStartSec = clamped;
      _activePlayedFrom = utc;
      _activeVnDayKey = dayKey;
      _activeQuestSetId = questSetId;
      return;
    }

    if (_activeVnDayKey != dayKey || _activeQuestSetId != questSetId) {
      cutSegment(clamped, utc);
      _activeStartSec = clamped;
      _activePlayedFrom = utc;
      _activeVnDayKey = dayKey;
      _activeQuestSetId = questSetId;
    }
  }

  /// Closes the current active segment at [endPositionSeconds] and queues it for reporting.
  /// Returns true if a valid non-empty segment was created.
  bool cutSegment(double endPositionSeconds, DateTime nowUtc) {
    final start = _activeStartSec;
    final from = _activePlayedFrom;
    final questSetId = _activeQuestSetId;
    _activeStartSec = null;
    _activePlayedFrom = null;
    _activeVnDayKey = null;
    _activeQuestSetId = null;

    if (start == null || from == null) return false;
    final end = _clamp(endPositionSeconds);
    final to = nowUtc.toUtc();
    final roundedStart = roundToMillis(start);
    final roundedEnd = roundToMillis(end);
    if (roundedEnd <= roundedStart || !to.isAfter(from)) {
      return false;
    }
    _pending.add(
      _TaggedSegment(
        questSetId,
        PlaybackSegment(
          eventSeq: _nextEventSeq++,
          startSecond: roundedStart,
          endSecond: roundedEnd,
          playedFrom: from,
          playedTo: to,
        ),
      ),
    );
    return true;
  }

  /// Removes segments that have been confirmed by the server up to [maxEventSeq].
  void acknowledgeUpTo(int maxEventSeq) {
    _pending.removeWhere((s) => s.segment.eventSeq <= maxEventSeq);
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
