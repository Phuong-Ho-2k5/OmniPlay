package com.omniplay.dto.request;

public record MysteryBoxDrawRequest(
        String mediaType,
        String genreId,
        Integer maxDurationSeconds,
        String excludeMediaId) {}
