package com.omniplay.playback;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.request.CreatePlaybackAttemptRequest;
import com.omniplay.dto.request.PlaybackReportRequest;
import com.omniplay.dto.request.PlaybackSegmentRequest;
import com.omniplay.dto.response.PlaybackAttemptResponse;
import com.omniplay.dto.response.PlaybackProgressResponse;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PlaybackProgressService {
    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(3);

    private final PlaybackProgressRepository repository;
    private final CatalogInputValidator validator;
    private final PlaybackProperties properties;
    private final Clock clock;

    public PlaybackProgressService(PlaybackProgressRepository repository, CatalogInputValidator validator,
            PlaybackProperties properties, Clock clock) {
        this.repository = repository;
        this.validator = validator;
        this.properties = properties;
        this.clock = clock;
    }

    @Transactional
    public AttemptResult createOrVerifyAttempt(UUID userId, CreatePlaybackAttemptRequest request) {
        if (request == null) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, Map.of("attemptId", "Thiếu dữ liệu lượt phát."));
        }
        UUID attemptId = validator.uuid(request.attemptId(), "attemptId");
        UUID mediaId = validator.uuid(request.mediaId(), "mediaId");
        UUID playlistItemId = request.playlistItemId() == null
                ? null
                : validator.uuid(request.playlistItemId(), "playlistItemId");

        // Check existing attempt first so removed playlist items still pass idempotent retry.
        var existing = repository.findAttempt(attemptId);
        if (existing.isPresent()) {
            return verifyExistingAttempt(existing.get(), userId, mediaId, playlistItemId);
        }

        if (repository.findAvailableMediaDuration(mediaId).isEmpty()) {
            throw new ApiException(ErrorCode.MEDIA_UNAVAILABLE);
        }
        if (playlistItemId != null && !repository.verifyPlaylistItemOwnership(userId, playlistItemId, mediaId)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }

        Instant startedAt = clock.instant().truncatedTo(ChronoUnit.MICROS);
        try {
            repository.insertAttempt(attemptId, userId, mediaId, playlistItemId, startedAt);
            return new AttemptResult(
                    new PlaybackAttemptResponse(attemptId, mediaId, playlistItemId, startedAt), true);
        } catch (DataIntegrityViolationException concurrent) {
            var raced = repository.findAttempt(attemptId)
                    .orElseThrow(() -> concurrent);
            return verifyExistingAttempt(raced, userId, mediaId, playlistItemId);
        }
    }

    private AttemptResult verifyExistingAttempt(PlaybackProgressRepository.AttemptRecord existing,
            UUID userId, UUID mediaId, UUID playlistItemId) {
        if (!existing.userId().equals(userId)
                || !existing.mediaId().equals(mediaId)
                || !Objects.equals(existing.initialPlaylistItemId(), playlistItemId)) {
            throw new ApiException(ErrorCode.REQUEST_CONFLICT);
        }
        return new AttemptResult(
                new PlaybackAttemptResponse(existing.attemptId(), existing.mediaId(),
                        existing.playlistItemId(), existing.startedAt()),
                false);
    }

    @Transactional
    public PlaybackProgressResponse reportProgress(UUID userId, UUID mediaId, PlaybackReportRequest request) {
        if (request == null) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, Map.of("attemptId", "Thiếu dữ liệu báo cáo phát."));
        }
        UUID attemptId = validator.uuid(request.attemptId(), "attemptId");
        UUID questSetId = request.questSetId() == null
                ? null
                : validator.uuid(request.questSetId(), "questSetId");

        var attempt = repository.findAttempt(attemptId)
                .filter(a -> a.userId().equals(userId) && a.mediaId().equals(mediaId))
                .orElseThrow(() -> new ApiException(ErrorCode.ATTEMPT_NOT_FOUND));

        int durationSeconds = repository.findMediaDuration(mediaId)
                .orElseThrow(() -> new ApiException(ErrorCode.MEDIA_UNAVAILABLE));
        BigDecimal maxDuration = BigDecimal.valueOf(durationSeconds).setScale(3);

        if (questSetId != null && !repository.questSetBelongsToUser(userId, questSetId)) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of("questSetId", "Bộ Quest không hợp lệ hoặc không thuộc tài khoản hiện tại."));
        }

        BigDecimal resumePosition = normalizeSeconds(request.resumePositionSeconds(), "resumePositionSeconds");
        if (resumePosition.compareTo(ZERO) < 0 || resumePosition.compareTo(maxDuration) > 0) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of("resumePositionSeconds", "Vị trí tiếp tục phải nằm trong [0, " + durationSeconds + "]."));
        }

        Instant receivedAt = clock.instant().truncatedTo(ChronoUnit.MICROS);
        Instant earliestAllowed = attempt.startedAt().minusSeconds(Math.max(0, properties.getClockSkewSeconds()));

        List<PlaybackSegmentRequest> rawSegments = request.segments() == null ? List.of() : request.segments();
        Map<Long, NormalizedSegment> incoming = new LinkedHashMap<>();
        for (int i = 0; i < rawSegments.size(); i++) {
            PlaybackSegmentRequest seg = rawSegments.get(i);
            String prefix = "segments[" + i + "]";
            if (seg == null || seg.eventSeq() == null || seg.eventSeq() < 0) {
                throw new ApiException(ErrorCode.VALIDATION_ERROR,
                        Map.of(prefix + ".eventSeq", "eventSeq phải là số nguyên không âm."));
            }
            BigDecimal start = normalizeSeconds(seg.startSecond(), prefix + ".startSecond");
            BigDecimal end = normalizeSeconds(seg.endSecond(), prefix + ".endSecond");
            if (start.compareTo(ZERO) < 0 || end.compareTo(start) <= 0 || end.compareTo(maxDuration) > 0) {
                throw new ApiException(ErrorCode.VALIDATION_ERROR,
                        Map.of(prefix, "Đoạn phát phải thỏa 0 <= startSecond < endSecond <= " + durationSeconds + "."));
            }
            Instant playedFrom = parseUtcInstant(seg.playedFrom(), prefix + ".playedFrom");
            Instant playedTo = parseUtcInstant(seg.playedTo(), prefix + ".playedTo");
            if (!playedTo.isAfter(playedFrom) || playedTo.isAfter(receivedAt) || playedFrom.isBefore(earliestAllowed)) {
                throw new ApiException(ErrorCode.VALIDATION_ERROR,
                        Map.of(prefix, "Thời điểm phát không hợp lệ so với lượt phát và đồng hồ máy chủ."));
            }
            var normalized = new NormalizedSegment(seg.eventSeq(), questSetId, start, end, playedFrom, playedTo);
            var duplicateInPayload = incoming.putIfAbsent(seg.eventSeq(), normalized);
            if (duplicateInPayload != null && !duplicateInPayload.equals(normalized)) {
                throw new ApiException(ErrorCode.EVENT_CONFLICT);
            }
        }

        var progress = repository.ensureAndLockProgress(userId, mediaId);
        var existingSegments = repository.findSegmentsByAttempt(attemptId);

        for (NormalizedSegment seg : incoming.values()) {
            var stored = existingSegments.get(seg.eventSeq());
            if (stored != null) {
                if (!matchesStored(seg, stored)) {
                    throw new ApiException(ErrorCode.EVENT_CONFLICT);
                }
                continue;
            }
            repository.insertSegment(progress.progressId(), attemptId, seg.eventSeq(), seg.questSetId(),
                    seg.startSecond(), seg.endSecond(), seg.playedFrom(), seg.playedTo(), receivedAt);
        }

        BigDecimal coveredSeconds = PlaybackSegmentMerger.mergeTotalSeconds(
                repository.findAllIntervals(progress.progressId()));
        boolean completed = PlaybackSegmentMerger.isCompleted(coveredSeconds, durationSeconds);

        repository.updateProgress(progress.progressId(), resumePosition, coveredSeconds, completed, receivedAt);

        return new PlaybackProgressResponse(
                mediaId,
                strip(resumePosition),
                strip(coveredSeconds),
                completed,
                List.of());
    }

    private BigDecimal normalizeSeconds(BigDecimal value, String field) {
        if (value == null) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, Map.of(field, "Thiếu giá trị số giây."));
        }
        BigDecimal stripped = value.stripTrailingZeros();
        if (stripped.scale() > 3) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of(field, "Số giây chỉ chấp nhận tối đa 3 chữ số thập phân."));
        }
        return value.setScale(3);
    }

    private Instant parseUtcInstant(String raw, String field) {
        if (raw == null || raw.isBlank()) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, Map.of(field, "Thời điểm phải là chuỗi ISO 8601 UTC."));
        }
        try {
            return Instant.parse(raw).truncatedTo(ChronoUnit.MICROS);
        } catch (DateTimeParseException e) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, Map.of(field, "Thời điểm phải đúng định dạng ISO 8601 UTC."));
        }
    }

    private boolean matchesStored(NormalizedSegment incoming, PlaybackProgressRepository.StoredSegment stored) {
        return Objects.equals(incoming.questSetId(), stored.questSetId())
                && incoming.startSecond().compareTo(stored.startSecond()) == 0
                && incoming.endSecond().compareTo(stored.endSecond()) == 0
                && incoming.playedFrom().equals(stored.playedFrom())
                && incoming.playedTo().equals(stored.playedTo());
    }

    private BigDecimal strip(BigDecimal value) {
        BigDecimal s = value.stripTrailingZeros();
        return s.scale() < 0 ? s.setScale(0) : s;
    }

    private record NormalizedSegment(
            long eventSeq,
            UUID questSetId,
            BigDecimal startSecond,
            BigDecimal endSecond,
            Instant playedFrom,
            Instant playedTo) {}

    public record AttemptResult(PlaybackAttemptResponse response, boolean created) {}
}
