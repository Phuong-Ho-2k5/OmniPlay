package com.omniplay.dto.request;

import java.math.BigDecimal;
import java.util.List;

public record SaveListeningSessionRequest(
        String currentMediaId,
        BigDecimal positionSeconds,
        List<String> queue,
        PlaybackReportRequest playbackReport) {}
