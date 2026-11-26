package com.omniplay.saved;

import com.omniplay.catalog.ContentType;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.response.PageResponse;
import com.omniplay.dto.response.SavedContentSummaryResponse;
import com.omniplay.dto.response.SavedStateResponse;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SavedService {
    private final SavedRepository repository;

    public SavedService(SavedRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public PageResponse<SavedContentSummaryResponse> list(UUID userId, int page, int size) {
        return repository.findSavedPage(userId, page, size);
    }

    @Transactional
    public SavedStateResponse setSaved(UUID userId, UUID id, ContentType type, boolean saved) {
        if (type == ContentType.POST) {
            if (saved) {
                if (!repository.isPostAvailable(id)) {
                    throw new ApiException(ErrorCode.CONTENT_UNAVAILABLE);
                }
                repository.savePost(userId, id);
            } else {
                repository.unsavePost(userId, id);
            }
        } else {
            if (saved) {
                if (!repository.isMediaAvailableWithType(id, type)) {
                    throw new ApiException(ErrorCode.CONTENT_UNAVAILABLE);
                }
                repository.saveMedia(userId, id);
            } else {
                repository.unsaveMedia(userId, id);
            }
        }
        return new SavedStateResponse(id, type, saved);
    }
}
