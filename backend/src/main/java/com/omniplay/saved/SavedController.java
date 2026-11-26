package com.omniplay.saved;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.request.UpdateSavedRequest;
import com.omniplay.dto.response.PageResponse;
import com.omniplay.dto.response.SavedContentSummaryResponse;
import com.omniplay.dto.response.SavedStateResponse;
import java.util.Map;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/me/saved")
public class SavedController {
    private final SavedService service;
    private final CatalogInputValidator input;

    public SavedController(SavedService service, CatalogInputValidator input) {
        this.service = service;
        this.input = input;
    }

    @GetMapping
    public PageResponse<SavedContentSummaryResponse> list(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) String page,
            @RequestParam(required = false) String size) {
        var query = input.parse(null, null, null, page, size, false);
        return service.list(UUID.fromString(jwt.getSubject()), query.page(), query.size());
    }

    @PutMapping("/{id}")
    public SavedStateResponse setSaved(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String id,
            @RequestBody UpdateSavedRequest request) {
        UUID contentId = input.uuid(id, "id");
        if (request == null || request.saved() == null) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of("saved", "Trạng thái lưu (saved) là bắt buộc."));
        }
        var parsed = input.parse(null, request.type(), null, null, null, true);
        return service.setSaved(UUID.fromString(jwt.getSubject()), contentId, parsed.type(), request.saved());
    }
}
