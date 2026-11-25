package com.omniplay.playback;

import com.omniplay.catalog.ContentType;
import com.omniplay.dto.response.ListeningSessionResponse;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ListeningSessionRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public ListeningSessionRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void lockUser(UUID userId) {
        jdbc.query("SELECT user_id FROM users WHERE user_id = :userId FOR UPDATE",
                Map.of("userId", userId), (rs, rowNum) -> rs.getObject("user_id", UUID.class));
    }

    public Optional<SessionRow> findSession(UUID userId, ListeningSessionType type) {
        String sql = """
                SELECT session_id, current_media_id, position_seconds, is_paused
                FROM listening_sessions
                WHERE user_id = :userId AND session_type = CAST(:type AS listening_kind)
                """;
        return jdbc.query(sql, Map.of("userId", userId, "type", type.dbValue()), (rs, rowNum) -> new SessionRow(
                rs.getObject("session_id", UUID.class),
                rs.getObject("current_media_id", UUID.class),
                rs.getBigDecimal("position_seconds"),
                rs.getBoolean("is_paused"))).stream().findFirst();
    }

    public List<ListeningSessionResponse.QueueItem> findQueue(UUID sessionId) {
        String sql = """
                SELECT media_id, position
                FROM listening_queue_items
                WHERE session_id = :sessionId
                ORDER BY position ASC
                """;
        return jdbc.query(sql, Map.of("sessionId", sessionId), (rs, rowNum) ->
                new ListeningSessionResponse.QueueItem(
                        rs.getObject("media_id", UUID.class),
                        rs.getInt("position")));
    }

    public UUID upsertAndLockSession(UUID userId, ListeningSessionType type, UUID currentMediaId,
            BigDecimal positionSeconds, Instant updatedAt) {
        var params = new MapSqlParameterSource()
                .addValue("userId", userId)
                .addValue("type", type.dbValue())
                .addValue("currentMediaId", currentMediaId)
                .addValue("positionSeconds", positionSeconds)
                .addValue("updatedAt", Timestamp.from(updatedAt));
        jdbc.update("""
                INSERT INTO listening_sessions (user_id, session_type, current_media_id, position_seconds, is_paused, updated_at)
                VALUES (:userId, CAST(:type AS listening_kind), :currentMediaId, :positionSeconds, TRUE, :updatedAt)
                ON CONFLICT (user_id, session_type) DO UPDATE
                SET current_media_id = EXCLUDED.current_media_id,
                    position_seconds = EXCLUDED.position_seconds,
                    is_paused = TRUE,
                    updated_at = EXCLUDED.updated_at
                """, params);
        return jdbc.queryForObject("""
                SELECT session_id
                FROM listening_sessions
                WHERE user_id = :userId AND session_type = CAST(:type AS listening_kind)
                FOR UPDATE
                """, Map.of("userId", userId, "type", type.dbValue()), UUID.class);
    }

    public void replaceQueue(UUID sessionId, List<UUID> queueMediaIds) {
        jdbc.update("DELETE FROM listening_queue_items WHERE session_id = :sessionId",
                Map.of("sessionId", sessionId));
        if (queueMediaIds.isEmpty()) return;
        MapSqlParameterSource[] batch = new MapSqlParameterSource[queueMediaIds.size()];
        for (int i = 0; i < queueMediaIds.size(); i++) {
            batch[i] = new MapSqlParameterSource()
                    .addValue("sessionId", sessionId)
                    .addValue("mediaId", queueMediaIds.get(i))
                    .addValue("position", i);
        }
        jdbc.batchUpdate("""
                INSERT INTO listening_queue_items (session_id, media_id, position)
                VALUES (:sessionId, :mediaId, :position)
                """, batch);
    }

    public Map<UUID, MediaInfo> findAvailableMedia(Collection<UUID> ids) {
        if (ids.isEmpty()) return Map.of();
        Map<UUID, MediaInfo> result = new HashMap<>();
        jdbc.query("""
                SELECT media_id, media_type::text AS media_type, duration_seconds
                FROM media
                WHERE media_id IN (:ids) AND is_available = TRUE
                """, Map.of("ids", ids), rs -> {
            UUID id = rs.getObject("media_id", UUID.class);
            result.put(id, new MediaInfo(
                    id,
                    ContentType.valueOf(rs.getString("media_type")),
                    rs.getInt("duration_seconds")));
        });
        return result;
    }

    public record SessionRow(UUID sessionId, UUID currentMediaId, BigDecimal positionSeconds, boolean isPaused) {}
    public record MediaInfo(UUID mediaId, ContentType type, int durationSeconds) {}
}
