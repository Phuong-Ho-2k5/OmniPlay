package com.omniplay.playback;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.request.SaveListeningSessionRequest;
import com.omniplay.dto.response.ListeningSessionResponse;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ListeningSessionService {
    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(3);

    private final ListeningSessionRepository repository;
    private final PlaybackProgressService progressService;
    private final CatalogInputValidator validator;
    private final Clock clock;

    public ListeningSessionService(ListeningSessionRepository repository, PlaybackProgressService progressService,
            CatalogInputValidator validator, Clock clock) {
        this.repository = repository;
        this.progressService = progressService;
        this.validator = validator;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public ListeningSessionResponse getSession(UUID userId, ListeningSessionType type) {
        var session = repository.findSession(userId, type);
        if (session.isEmpty()) {
            return new ListeningSessionResponse(type.apiValue(), null, BigDecimal.ZERO, true, List.of());
        }
        var row = session.get();
        var queue = type == ListeningSessionType.MUSIC ? repository.findQueue(row.sessionId()) : List.<ListeningSessionResponse.QueueItem>of();
        return new ListeningSessionResponse(
                type.apiValue(),
                row.currentMediaId(),
                strip(row.positionSeconds()),
                row.isPaused(),
                queue);
    }

    @Transactional
    public ListeningSessionResponse saveSession(UUID userId, ListeningSessionType type,
            SaveListeningSessionRequest request) {
        if (request == null) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, Map.of("positionSeconds", "Thiếu dữ liệu phiên nghe."));
        }
        UUID currentMediaId = request.currentMediaId() == null
                ? null
                : validator.uuid(request.currentMediaId(), "currentMediaId");
        BigDecimal position = normalizeSeconds(request.positionSeconds(), "positionSeconds");

        List<String> rawQueue = request.queue() == null ? List.of() : request.queue();
        List<UUID> queueIds = new ArrayList<>(rawQueue.size());
        for (int i = 0; i < rawQueue.size(); i++) {
            queueIds.add(validator.uuid(rawQueue.get(i), "queue[" + i + "]"));
        }

        if (type == ListeningSessionType.PODCAST && !queueIds.isEmpty()) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of("queue", "Phiên podcast phải có hàng đợi rỗng."));
        }
        if (currentMediaId == null) {
            if (position.compareTo(ZERO) != 0) {
                throw new ApiException(ErrorCode.VALIDATION_ERROR,
                        Map.of("positionSeconds", "Phiên rỗng phải có positionSeconds bằng 0."));
            }
            if (!queueIds.isEmpty()) {
                throw new ApiException(ErrorCode.VALIDATION_ERROR,
                        Map.of("queue", "Phiên rỗng phải có hàng đợi rỗng."));
            }
        } else {
            Set<UUID> toCheck = new LinkedHashSet<>();
            toCheck.add(currentMediaId);
            toCheck.addAll(queueIds);
            var available = repository.findAvailableMedia(toCheck);

            var currentMedia = available.get(currentMediaId);
            if (currentMedia == null) {
                throw new ApiException(ErrorCode.MEDIA_UNAVAILABLE);
            }
            if (currentMedia.type() != type.mediaType()) {
                throw new ApiException(ErrorCode.VALIDATION_ERROR,
                        Map.of("currentMediaId", "Nội dung không khớp loại phiên " + type.apiValue() + "."));
            }
            BigDecimal maxDuration = BigDecimal.valueOf(currentMedia.durationSeconds()).setScale(3);
            if (position.compareTo(ZERO) < 0 || position.compareTo(maxDuration) > 0) {
                throw new ApiException(ErrorCode.VALIDATION_ERROR,
                        Map.of("positionSeconds", "Vị trí phát phải nằm trong [0, " + currentMedia.durationSeconds() + "]."));
            }
            for (int i = 0; i < queueIds.size(); i++) {
                var item = available.get(queueIds.get(i));
                if (item == null) {
                    throw new ApiException(ErrorCode.MEDIA_UNAVAILABLE);
                }
                if (item.type() != type.mediaType()) {
                    throw new ApiException(ErrorCode.VALIDATION_ERROR,
                            Map.of("queue[" + i + "]", "Hàng đợi chỉ chấp nhận nội dung loại " + type.apiValue() + "."));
                }
            }
        }

        // Lock user -> session, save paused state, replace queue, and process optional report in one transaction.
        repository.lockUser(userId);
        Instant now = clock.instant().truncatedTo(ChronoUnit.MICROS);
        UUID sessionId = repository.upsertAndLockSession(userId, type, currentMediaId, position, now);
        repository.replaceQueue(sessionId, type == ListeningSessionType.MUSIC ? queueIds : List.of());

        if (request.playbackReport() != null) {
            if (currentMediaId == null) {
                throw new ApiException(ErrorCode.VALIDATION_ERROR,
                        Map.of("playbackReport", "Không thể gửi báo cáo phát khi phiên rỗng."));
            }
            progressService.reportProgress(userId, currentMediaId, request.playbackReport());
        }

        List<ListeningSessionResponse.QueueItem> queueResponse = new ArrayList<>(queueIds.size());
        if (type == ListeningSessionType.MUSIC) {
            for (int i = 0; i < queueIds.size(); i++) {
                queueResponse.add(new ListeningSessionResponse.QueueItem(queueIds.get(i), i));
            }
        }
        return new ListeningSessionResponse(type.apiValue(), currentMediaId, strip(position), true, queueResponse);
    }

    private BigDecimal normalizeSeconds(BigDecimal value, String field) {
        if (value == null) return ZERO;
        BigDecimal stripped = value.stripTrailingZeros();
        if (stripped.scale() > 3) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of(field, "Số giây chỉ chấp nhận tối đa 3 chữ số thập phân."));
        }
        return value.setScale(3);
    }

    private BigDecimal strip(BigDecimal value) {
        if (value == null) return BigDecimal.ZERO;
        BigDecimal s = value.stripTrailingZeros();
        return s.scale() < 0 ? s.setScale(0) : s;
    }
}
