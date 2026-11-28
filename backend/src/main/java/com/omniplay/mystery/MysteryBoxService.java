package com.omniplay.mystery;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.catalog.ContentType;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.request.MysteryBoxDrawRequest;
import com.omniplay.dto.response.MysteryBoxDrawResponse;
import java.security.SecureRandom;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MysteryBoxService {
    private final MysteryBoxRepository repository;
    private final CatalogInputValidator validator;
    private final SecureRandom random = new SecureRandom();

    public MysteryBoxService(MysteryBoxRepository repository, CatalogInputValidator validator) {
        this.repository = repository;
        this.validator = validator;
    }

    @Transactional(readOnly = true)
    public MysteryBoxDrawResponse draw(UUID userId, MysteryBoxDrawRequest request) {
        ContentType mediaType = null;
        UUID genreId = null;
        Integer maxDurationSeconds = null;
        UUID excludeMediaId = null;

        if (request != null) {
            mediaType = parseMediaType(request.mediaType());
            if (request.genreId() != null && !request.genreId().isBlank()) {
                genreId = validator.uuid(request.genreId(), "genreId");
            }
            if (request.maxDurationSeconds() != null) {
                if (request.maxDurationSeconds() <= 0) {
                    throw new ApiException(ErrorCode.VALIDATION_ERROR,
                            Map.of("maxDurationSeconds", "Thời lượng tối đa phải lớn hơn 0 giây."));
                }
                maxDurationSeconds = request.maxDurationSeconds();
            }
            if (request.excludeMediaId() != null && !request.excludeMediaId().isBlank()) {
                excludeMediaId = validator.uuid(request.excludeMediaId(), "excludeMediaId");
            }
        }

        List<UUID> matchingIds = repository.findMatchingAvailableMediaIds(mediaType, genreId, maxDurationSeconds);
        if (matchingIds.isEmpty()) {
            return new MysteryBoxDrawResponse("EMPTY", null);
        }

        UUID excluded = excludeMediaId;
        List<UUID> alternatives = excluded == null
                ? matchingIds
                : matchingIds.stream().filter(id -> !id.equals(excluded)).toList();

        if (!alternatives.isEmpty()) {
            UUID pickedId = alternatives.get(random.nextInt(alternatives.size()));
            var summary = repository.findMediaSummary(userId, pickedId).orElse(null);
            if (summary == null) {
                return new MysteryBoxDrawResponse("EMPTY", null);
            }
            return new MysteryBoxDrawResponse("FOUND", summary);
        }

        if (excluded != null && matchingIds.contains(excluded)) {
            var summary = repository.findMediaSummary(userId, excluded).orElse(null);
            if (summary != null) {
                return new MysteryBoxDrawResponse("NO_ALTERNATIVE", summary);
            }
        }

        return new MysteryBoxDrawResponse("EMPTY", null);
    }

    private ContentType parseMediaType(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            ContentType parsed = ContentType.valueOf(raw.trim().toUpperCase());
            if (parsed == ContentType.POST) {
                throw new ApiException(ErrorCode.VALIDATION_ERROR,
                        Map.of("mediaType", "Mystery Box chỉ áp dụng cho VIDEO, MUSIC hoặc PODCAST."));
            }
            return parsed;
        } catch (IllegalArgumentException e) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of("mediaType", "Loại media phải là VIDEO, MUSIC hoặc PODCAST."));
        }
    }
}
