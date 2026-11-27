package com.omniplay.playlist;

import com.omniplay.dto.response.CleanupSuggestionListResponse.CleanupSuggestionItemResponse;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class CleanupSuggestionRepository {
    private static final int CLEANUP_SUGGESTION_THRESHOLD = 6;

    private final NamedParameterJdbcTemplate jdbc;

    public CleanupSuggestionRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<CleanupSuggestionItemResponse> findVisibleByUser(UUID userId) {
        String sql = """
                SELECT pi.playlist_item_id, pi.playlist_id, pi.media_id, m.title, pi.skip_count
                FROM playlist_items pi
                JOIN playlists p ON p.playlist_id = pi.playlist_id
                JOIN media m ON m.media_id = pi.media_id
                WHERE p.user_id = :userId
                  AND pi.skip_count >= :threshold
                  AND pi.suggestion_dismissed = FALSE
                ORDER BY pi.skip_count DESC, pi.playlist_id ASC, pi.playlist_item_id ASC
                """;
        return jdbc.query(sql, Map.of("userId", userId, "threshold", CLEANUP_SUGGESTION_THRESHOLD),
                (rs, rowNum) -> new CleanupSuggestionItemResponse(
                        rs.getObject("playlist_item_id", UUID.class),
                        rs.getObject("playlist_id", UUID.class),
                        rs.getObject("media_id", UUID.class),
                        rs.getString("title"),
                        rs.getInt("skip_count")));
    }

    public boolean lockUser(UUID userId) {
        return !jdbc.query(
                "SELECT user_id FROM users WHERE user_id = :userId FOR UPDATE",
                Map.of("userId", userId),
                (rs, rowNum) -> rs.getObject("user_id", UUID.class)).isEmpty();
    }

    public Optional<LockedCleanupItem> lockItemWithOwner(UUID playlistItemId) {
        String sql = """
                SELECT pi.playlist_item_id, pi.playlist_id, p.user_id, pi.skip_count, pi.suggestion_dismissed
                FROM playlist_items pi
                JOIN playlists p ON p.playlist_id = pi.playlist_id
                WHERE pi.playlist_item_id = :playlistItemId
                FOR UPDATE OF pi
                """;
        return jdbc.query(sql, Map.of("playlistItemId", playlistItemId), (rs, rowNum) -> new LockedCleanupItem(
                rs.getObject("playlist_item_id", UUID.class),
                rs.getObject("playlist_id", UUID.class),
                rs.getObject("user_id", UUID.class),
                rs.getInt("skip_count"),
                rs.getBoolean("suggestion_dismissed")))
                .stream().findFirst();
    }

    public void resetSkipCount(UUID playlistItemId) {
        jdbc.update("""
                UPDATE playlist_items
                SET skip_count = 0,
                    suggestion_dismissed = FALSE
                WHERE playlist_item_id = :playlistItemId
                """, Map.of("playlistItemId", playlistItemId));
    }

    public void dismissSuggestion(UUID playlistItemId) {
        jdbc.update("""
                UPDATE playlist_items
                SET suggestion_dismissed = TRUE
                WHERE playlist_item_id = :playlistItemId
                """, Map.of("playlistItemId", playlistItemId));
    }

    public void removeItem(UUID playlistItemId, UUID playlistId, Instant now) {
        int removed = jdbc.update(
                "DELETE FROM playlist_items WHERE playlist_item_id = :playlistItemId",
                Map.of("playlistItemId", playlistItemId));
        if (removed > 0) {
            jdbc.update(
                    "UPDATE playlists SET updated_at = :now WHERE playlist_id = :playlistId",
                    Map.of("now", Timestamp.from(now), "playlistId", playlistId));
        }
    }

    public record LockedCleanupItem(
            UUID playlistItemId,
            UUID playlistId,
            UUID userId,
            int skipCount,
            boolean suggestionDismissed) {}
}
