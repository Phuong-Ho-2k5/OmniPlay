package com.omniplay.catalog;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.response.*;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
public class CatalogService {
    private final CatalogQueryRepository repository;
    public CatalogService(CatalogQueryRepository repository) { this.repository = repository; }

    public PageResponse<ContentSummaryResponse> list(UUID userId, CatalogQuery query) {
        return repository.findPage(userId, query);
    }
    public ContentDetailResponse detail(UUID userId, UUID id, ContentType type) {
        return repository.findDetail(userId, id, type).orElseThrow(() -> new ApiException(ErrorCode.CONTENT_UNAVAILABLE));
    }
    public GenreListResponse genres() { return new GenreListResponse(repository.findGenres()); }
}
