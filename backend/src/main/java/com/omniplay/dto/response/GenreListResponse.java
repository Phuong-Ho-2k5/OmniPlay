package com.omniplay.dto.response;

import java.util.List;

public record GenreListResponse(List<GenreResponse> items) {
    public GenreListResponse { items = List.copyOf(items); }
}
