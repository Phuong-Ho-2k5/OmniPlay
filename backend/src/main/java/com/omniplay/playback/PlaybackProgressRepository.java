package com.omniplay.playback;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class PlaybackProgressRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public PlaybackProgressRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<AttemptRecord> findAttempt(UUID attemptId) {
        String sql = """
                SELECT attempt_id, user_id, media_id, playlist_item_id, initial_playlist_item_id, started_at
                FROM playback_attempts
                WHERE attempt_id = :attemptId
                """;
        return jdbc.query(sql, Map.of("attemptId", attemptId), (rs, rowNum) -> new AttemptRecord(
                rs.getObject("attempt_id", UUID.class),
                rs.getObject("user_id", UUID.class),
                rs.getObject("media_id", UUID.class),
                rs.getObject("playlist_item_id", UUID.class),
                rs.getObject("initial_playlist_item_id", UUID.class),
                rs.getTimestamp("started_at").toInstant().truncatedTo(ChronoUnit.MICROS)))
                .stream().findFirst();
    }

    public Optional<Integer> findAvailableMediaDuration(UUID mediaId) {
        return jdbc.query(
                "SELECT duration_seconds FROM media WHERE media_id = :mediaId AND is_available = TRUE",
                Map.of("mediaId", mediaId),
                (rs, rowNum) -> rs.getInt("duration_seconds")).stream().findFirst();
    }

    public Optional<Integer> findMediaDuration(UUID mediaId) {
        return jdbc.query(
                "SELECT duration_seconds FROM media WHERE media_id = :mediaId",
                Map.of("mediaId", mediaId),
                (rs, rowNum) -> rs.getInt("duration_seconds")).stream().findFirst();
    }

    public boolean verifyPlaylistItemOwnership(UUID userId, UUID playlistItemId, UUID mediaId) {
        String sql = """
                SELECT 1
                FROM playlist_items pi
                JOIN playlists p ON p.playlist_id = pi.playlist_id
                WHERE pi.playlist_item_id = :itemId
                  AND p.user_id = :userId
                  AND pi.media_id = :mediaId
                """;
        return !jdbc.query(sql,
                Map.of("itemId", playlistItemId, "userId", userId, "mediaId", mediaId),
                (rs, rowNum) -> 1).isEmpty();
    }

    public void insertAttempt(UUID attemptId, UUID userId, UUID mediaId, UUID playlistItemId, Instant startedAt) {
        String sql = """
                INSERT INTO playback_attempts (attempt_id, user_id, media_id, playlist_item_id, initial_playlist_item_id, started_at)
                VALUES (:attemptId, :userId, :mediaId, :playlistItemId, :initialPlaylistItemId, :startedAt)
                """;
        var params = new MapSqlParameterSource()
                .addValue("attemptId", attemptId)
                .addValue("userId", userId)
                .addValue("mediaId", mediaId)
                .addValue("playlistItemId", playlistItemId)
                .addValue("initialPlaylistItemId", playlistItemId)
                .addValue("startedAt", Timestamp.from(startedAt));
        jdbc.update(sql, params);
    }

    public boolean questSetBelongsToUser(UUID userId, UUID questSetId) {
        return !jdbc.query(
                "SELECT 1 FROM daily_quest_sets WHERE quest_set_id = :questSetId AND user_id = :userId",
                Map.of("questSetId", questSetId, "userId", userId),
                (rs, rowNum) -> 1).isEmpty();
    }

    public ProgressRow ensureAndLockProgress(UUID userId, UUID mediaId) {
        jdbc.update("""
                INSERT INTO playback_progress (user_id, media_id)
                VALUES (:userId, :mediaId)
                ON CONFLICT (user_id, media_id) DO NOTHING
                """, Map.of("userId", userId, "mediaId", mediaId));
        return jdbc.queryForObject("""
                SELECT progress_id, resume_position_seconds, covered_seconds, completed
                FROM playback_progress
                WHERE user_id = :userId AND media_id = :mediaId
                FOR UPDATE
                """, Map.of("userId", userId, "mediaId", mediaId), (rs, rowNum) -> new ProgressRow(
                rs.getObject("progress_id", UUID.class),
                rs.getBigDecimal("resume_position_seconds"),
                rs.getBigDecimal("covered_seconds"),
                rs.getBoolean("completed")));
    }

    public Map<Long, StoredSegment> findSegmentsByAttempt(UUID attemptId) {
        Map<Long, StoredSegment> result = new HashMap<>();
        jdbc.query("""
                SELECT event_seq, quest_set_id, start_second, end_second, played_from, played_to
                FROM playback_segments
                WHERE attempt_id = :attemptId
                """, Map.of("attemptId", attemptId), rs -> {
            long seq = rs.getLong("event_seq");
            result.put(seq, new StoredSegment(
                    seq,
                    rs.getObject("quest_set_id", UUID.class),
                    rs.getBigDecimal("start_second"),
                    rs.getBigDecimal("end_second"),
                    rs.getTimestamp("played_from").toInstant().truncatedTo(ChronoUnit.MICROS),
                    rs.getTimestamp("played_to").toInstant().truncatedTo(ChronoUnit.MICROS)));
        });
        return result;
    }

    public void insertSegment(UUID progressId, UUID attemptId, long eventSeq, UUID questSetId,
            BigDecimal startSecond, BigDecimal endSecond, Instant playedFrom, Instant playedTo, Instant receivedAt) {
        var params = new MapSqlParameterSource()
                .addValue("progressId", progressId)
                .addValue("attemptId", attemptId)
                .addValue("eventSeq", eventSeq)
                .addValue("questSetId", questSetId)
                .addValue("startSecond", startSecond)
                .addValue("endSecond", endSecond)
                .addValue("playedFrom", Timestamp.from(playedFrom))
                .addValue("playedTo", Timestamp.from(playedTo))
                .addValue("receivedAt", Timestamp.from(receivedAt));
        jdbc.update("""
                INSERT INTO playback_segments
                    (progress_id, attempt_id, event_seq, quest_set_id, start_second, end_second, played_from, played_to, received_at)
                VALUES
                    (:progressId, :attemptId, :eventSeq, :questSetId, :startSecond, :endSecond, :playedFrom, :playedTo, :receivedAt)
                """, params);
    }

    public List<PlaybackSegmentMerger.Interval> findAllIntervals(UUID progressId) {
        return jdbc.query(
                "SELECT start_second, end_second FROM playback_segments WHERE progress_id = :progressId",
                Map.of("progressId", progressId),
                (rs, rowNum) -> new PlaybackSegmentMerger.Interval(
                        rs.getBigDecimal("start_second"),
                        rs.getBigDecimal("end_second")));
    }

    public void updateProgress(UUID progressId, BigDecimal resumePositionSeconds, BigDecimal coveredSeconds,
            boolean completed, Instant updatedAt) {
        var params = new MapSqlParameterSource()
                .addValue("progressId", progressId)
                .addValue("resume", resumePositionSeconds)
                .addValue("covered", coveredSeconds)
                .addValue("completed", completed)
                .addValue("updatedAt", Timestamp.from(updatedAt));
        jdbc.update("""
                UPDATE playback_progress
                SET resume_position_seconds = :resume,
                    covered_seconds = :covered,
                    completed = :completed,
                    updated_at = :updatedAt
                WHERE progress_id = :progressId
                """, params);
    }

    public record AttemptRecord(
            UUID attemptId,
            UUID userId,
            UUID mediaId,
            UUID playlistItemId,
            UUID initialPlaylistItemId,
            Instant startedAt) {}

    public record ProgressRow(
            UUID progressId,
            BigDecimal resumePositionSeconds,
            BigDecimal coveredSeconds,
            boolean completed) {}

    public record StoredSegment(
            long eventSeq,
            UUID questSetId,
            BigDecimal startSecond,
            BigDecimal endSecond,
            Instant playedFrom,
            Instant playedTo) {}
}
