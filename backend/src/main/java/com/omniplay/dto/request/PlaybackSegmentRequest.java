package com.omniplay.dto.request;

import java.math.BigDecimal;

public record PlaybackSegmentRequest(
        Long eventSeq,
        BigDecimal startSecond,
        BigDecimal endSecond,
        String playedFrom,
        String playedTo) {}
