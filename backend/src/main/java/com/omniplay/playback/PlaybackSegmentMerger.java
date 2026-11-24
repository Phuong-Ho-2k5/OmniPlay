package com.omniplay.playback;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public final class PlaybackSegmentMerger {
    private static final BigDecimal TEN = BigDecimal.TEN;
    private static final BigDecimal NINE = BigDecimal.valueOf(9);

    private PlaybackSegmentMerger() {}

    public record Interval(BigDecimal start, BigDecimal end) {}

    public static BigDecimal mergeTotalSeconds(List<Interval> intervals) {
        if (intervals == null || intervals.isEmpty()) {
            return BigDecimal.ZERO;
        }
        var sorted = new ArrayList<>(intervals);
        sorted.sort(Comparator.comparing(Interval::start).thenComparing(Interval::end));

        BigDecimal total = BigDecimal.ZERO;
        BigDecimal curStart = sorted.getFirst().start();
        BigDecimal curEnd = sorted.getFirst().end();

        for (int i = 1; i < sorted.size(); i++) {
            Interval next = sorted.get(i);
            if (next.start().compareTo(curEnd) <= 0) {
                if (next.end().compareTo(curEnd) > 0) {
                    curEnd = next.end();
                }
            } else {
                total = total.add(curEnd.subtract(curStart));
                curStart = next.start();
                curEnd = next.end();
            }
        }
        total = total.add(curEnd.subtract(curStart));
        return total.stripTrailingZeros().scale() < 0 ? total.setScale(0) : total.stripTrailingZeros();
    }

    public static boolean isCompleted(BigDecimal coveredSeconds, int durationSeconds) {
        if (durationSeconds <= 0 || coveredSeconds == null) return false;
        return coveredSeconds.multiply(TEN)
                .compareTo(BigDecimal.valueOf(durationSeconds).multiply(NINE)) >= 0;
    }
}
