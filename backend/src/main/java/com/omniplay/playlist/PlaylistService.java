package com.omniplay.playlist;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.request.CreatePlaylistRequest;
import com.omniplay.dto.request.RenamePlaylistRequest;
import com.omniplay.dto.response.PageResponse;
import com.omniplay.dto.response.PlaylistDetailResponse;
import com.omniplay.dto.response.PlaylistRenamedResponse;
import com.omniplay.dto.response.PlaylistSummaryResponse;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PlaylistService {
    private final PlaylistRepository repository;
    private final CatalogInputValidator validator;
    private final Clock clock;

    public PlaylistService(PlaylistRepository repository, CatalogInputValidator validator, Clock clock) {
        this.repository = repository;
        this.validator = validator;
        this.clock = clock;
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public PageResponse<PlaylistSummaryResponse> list(UUID userId, int page, int size) {
        return repository.findPage(userId, page, size);
    }

    @Transactional
    public CreateResult create(UUID userId, CreatePlaylistRequest request) {
        if (request == null) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, Map.of("name", "Tên playlist là bắt buộc."));
        }
        UUID playlistId = validator.uuid(request.requestId(), "requestId");
        String trimmedName = validateName(request.name());

        var existing = repository.findById(playlistId);
        if (existing.isPresent()) {
            return verifyExistingCreate(existing.get(), userId, trimmedName);
        }

        Instant now = clock.instant().truncatedTo(ChronoUnit.MICROS);
        try {
            repository.insert(playlistId, userId, trimmedName, now);
            return new CreateResult(new PlaylistSummaryResponse(playlistId, trimmedName, 0, now, now), true);
        } catch (DataIntegrityViolationException concurrent) {
            var raced = repository.findById(playlistId).orElseThrow(() -> concurrent);
            return verifyExistingCreate(raced, userId, trimmedName);
        }
    }

    private CreateResult verifyExistingCreate(PlaylistRepository.PlaylistRow row, UUID userId, String trimmedName) {
        if (!row.userId().equals(userId) || !row.creationName().equals(trimmedName)) {
            throw new ApiException(ErrorCode.REQUEST_CONFLICT);
        }
        return new CreateResult(row.summary(), false);
    }

    @Transactional(readOnly = true)
    public PlaylistDetailResponse detail(UUID userId, UUID playlistId) {
        var row = repository.findById(playlistId)
                .filter(p -> p.userId().equals(userId))
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        return new PlaylistDetailResponse(row.playlistId(), row.name(), repository.findItems(playlistId));
    }

    @Transactional
    public PlaylistRenamedResponse rename(UUID userId, UUID playlistId, RenamePlaylistRequest request) {
        if (request == null) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, Map.of("name", "Tên playlist là bắt buộc."));
        }
        String trimmedName = validateName(request.name());
        Instant now = clock.instant().truncatedTo(ChronoUnit.MICROS);
        int updated = repository.rename(playlistId, userId, trimmedName, now);
        if (updated == 0) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        return new PlaylistRenamedResponse(playlistId, trimmedName, now);
    }

    @Transactional
    public void delete(UUID userId, UUID playlistId) {
        var existing = repository.findById(playlistId);
        if (existing.isEmpty()) {
            return; // Idempotent 204 when already deleted or nonexistent
        }
        if (!existing.get().userId().equals(userId)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        repository.deleteById(playlistId);
    }

    private String validateName(String raw) {
        String trimmed = raw == null ? "" : raw.trim();
        if (trimmed.isEmpty()
                || trimmed.indexOf('\0') >= 0
                || !StandardCharsets.UTF_8.newEncoder().canEncode(trimmed)
                || trimmed.codePointCount(0, trimmed.length()) > 120) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of("name", "Tên playlist phải có từ 1 đến 120 ký tự."));
        }
        return trimmed;
    }

    public record CreateResult(PlaylistSummaryResponse playlist, boolean created) {}
}
