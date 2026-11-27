package com.omniplay.playback;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class PlaybackSkipRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public PlaybackSkipRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public boolean lockUser(UUID userId) {
        return !jdbc.query(
                "SELECT user_id FROM users WHERE user_id = :userId FOR UPDATE",
                Map.of("userId", userId),
                (rs, rowNum) -> rs.getObject("user_id", UUID.class)).isEmpty();
    }

    public Optional<AttemptLookup> findAttemptUnlocked(UUID attemptId) {
        String sql = """
                SELECT attempt_id, user_id, playlist_item_id
                FROM playback_attempts
                WHERE attempt_id = :attemptId
                """;
        return jdbc.query(sql, Map.of("attemptId", attemptId), (rs, rowNum) -> new AttemptLookup(
                rs.getObject("attempt_id", UUID.class),
                rs.getObject("user_id", UUID.class),
                rs.getObject("playlist_item_id", UUID.class)))
                .stream().findFirst();
    }

    public Optional<LockedPlaylistItem> lockOwnedPlaylistItem(UUID playlistItemId, UUID userId) {
        String sql = """
                SELECT pi.playlist_item_id, pi.playlist_id, pi.position, pi.skip_count, pi.suggestion_dismissed
                FROM playlist_items pi
                JOIN playlists p ON p.playlist_id = pi.playlist_id
                WHERE pi.playlist_item_id = :playlistItemId
                  AND p.user_id = :userId
                FOR UPDATE OF pi
                """;
        return jdbc.query(sql, Map.of("playlistItemId", playlistItemId, "userId", userId),
                (rs, rowNum) -> new LockedPlaylistItem(
                        rs.getObject("playlist_item_id", UUID.class),
                        rs.getObject("playlist_id", UUID.class),
                        rs.getInt("position"),
                        rs.getInt("skip_count"),
                        rs.getBoolean("suggestion_dismissed")))
                .stream().findFirst();
    }

    public Optional<LockedAttempt> lockAttempt(UUID attemptId) {
        String sql = """
                SELECT attempt_id, user_id, playlist_item_id, skip_recorded
                FROM playback_attempts
                WHERE attempt_id = :attemptId
                FOR UPDATE
                """;
        return jdbc.query(sql, Map.of("attemptId", attemptId), (rs, rowNum) -> new LockedAttempt(
                rs.getObject("attempt_id", UUID.class),
                rs.getObject("user_id", UUID.class),
                rs.getObject("playlist_item_id", UUID.class),
                rs.getBoolean("skip_recorded")))
                .stream().findFirst();
    }

    public boolean hasNextPlaylistItem(UUID playlistId, int currentPosition) {
        String sql = """
                SELECT 1
                FROM playlist_items
                WHERE playlist_id = :playlistId
                  AND position > :currentPosition
                LIMIT 1
                """;
        return !jdbc.query(sql, Map.of("playlistId", playlistId, "currentPosition", currentPosition),
                (rs, rowNum) -> 1).isEmpty();
    }

    public void markAttemptSkipRecorded(UUID attemptId) {
        jdbc.update(
                "UPDATE playback_attempts SET skip_recorded = TRUE WHERE attempt_id = :attemptId",
                Map.of("attemptId", attemptId));
    }

    public int incrementSkipCountAndResetDismissed(UUID playlistItemId) {
        Integer updated = jdbc.queryForObject("""
                UPDATE playlist_items
                SET skip_count = skip_count + 1,
                    suggestion_dismissed = FALSE
                WHERE playlist_item_id = :playlistItemId
                RETURNING skip_count
                """, Map.of("playlistItemId", playlistItemId), Integer.class);
        return updated == null ? 0 : updated;
    }

    public record AttemptLookup(UUID attemptId, UUID userId, UUID playlistItemId) {}

    public record LockedPlaylistItem(
            UUID playlistItemId,
            UUID playlistId,
            int position,
            int skipCount,
            boolean suggestionDismissed) {}

    public record LockedAttempt(
            UUID attemptId,
            UUID userId,
            UUID playlistItemId,
            boolean skipRecorded) {}
}
