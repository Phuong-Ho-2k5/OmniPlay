package com.omniplay.dto.request;

import java.math.BigDecimal;
import java.util.List;

public record PlaybackReportRequest(
        String attemptId,
        BigDecimal resumePositionSeconds,
        String questSetId,
        List<PlaybackSegmentRequest> segments) {}
