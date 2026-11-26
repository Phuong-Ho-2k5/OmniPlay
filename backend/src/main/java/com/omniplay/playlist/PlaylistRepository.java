package com.omniplay.playlist;

import com.omniplay.catalog.ContentType;
import com.omniplay.dto.response.PageResponse;
import com.omniplay.dto.response.PlaylistDetailResponse;
import com.omniplay.dto.response.PlaylistItemAddedResponse;
import com.omniplay.dto.response.PlaylistSummaryResponse;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class PlaylistRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public PlaylistRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public PageResponse<PlaylistSummaryResponse> findPage(UUID userId, int page, int size) {
        var params = new MapSqlParameterSource("userId", userId);
        Long total = jdbc.queryForObject(
                "SELECT count(*) FROM playlists WHERE user_id = :userId", params, Long.class);
        params.addValue("limit", size).addValue("offset", (long) page * size);
        String sql = """
                SELECT p.playlist_id, p.name, p.created_at, p.updated_at,
                       COUNT(pi.playlist_item_id) AS item_count
                FROM playlists p
                LEFT JOIN playlist_items pi ON pi.playlist_id = p.playlist_id
                WHERE p.user_id = :userId
                GROUP BY p.playlist_id, p.name, p.created_at, p.updated_at
                ORDER BY p.created_at DESC, p.playlist_id DESC
                LIMIT :limit OFFSET :offset
                """;
        var items = jdbc.query(sql, params, (rs, rowNum) -> new PlaylistSummaryResponse(
                rs.getObject("playlist_id", UUID.class),
                rs.getString("name"),
                rs.getInt("item_count"),
                rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("updated_at").toInstant()));
        return new PageResponse<>(items, page, size, total == null ? 0 : total);
    }

    public Optional<PlaylistRow> findById(UUID playlistId) {
        String sql = """
                SELECT p.playlist_id, p.user_id, p.name, p.creation_name, p.created_at, p.updated_at,
                       COUNT(pi.playlist_item_id) AS item_count
                FROM playlists p
                LEFT JOIN playlist_items pi ON pi.playlist_id = p.playlist_id
                WHERE p.playlist_id = :id
                GROUP BY p.playlist_id, p.user_id, p.name, p.creation_name, p.created_at, p.updated_at
                """;
        return jdbc.query(sql, Map.of("id", playlistId), (rs, rowNum) -> new PlaylistRow(
                rs.getObject("playlist_id", UUID.class),
                rs.getObject("user_id", UUID.class),
                rs.getString("name"),
                rs.getString("creation_name"),
                rs.getInt("item_count"),
                rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("updated_at").toInstant())).stream().findFirst();
    }

    public void insert(UUID playlistId, UUID userId, String trimmedName, Instant now) {
        var params = new MapSqlParameterSource()
                .addValue("id", playlistId)
                .addValue("userId", userId)
                .addValue("name", trimmedName)
                .addValue("creationName", trimmedName)
                .addValue("now", Timestamp.from(now));
        jdbc.update("""
                INSERT INTO playlists (playlist_id, user_id, name, creation_name, created_at, updated_at)
                VALUES (:id, :userId, :name, :creationName, :now, :now)
                """, params);
    }

    public int rename(UUID playlistId, UUID userId, String trimmedName, Instant updatedAt) {
        var params = new MapSqlParameterSource()
                .addValue("id", playlistId)
                .addValue("userId", userId)
                .addValue("name", trimmedName)
                .addValue("updatedAt", Timestamp.from(updatedAt));
        return jdbc.update("""
                UPDATE playlists
                SET name = :name, updated_at = :updatedAt
                WHERE playlist_id = :id AND user_id = :userId
                """, params);
    }

    public void deleteById(UUID playlistId) {
        jdbc.update("DELETE FROM playlists WHERE playlist_id = :id", Map.of("id", playlistId));
    }

    public boolean lockOwnedPlaylist(UUID playlistId, UUID userId) {
        return !jdbc.query(
                "SELECT playlist_id FROM playlists WHERE playlist_id = :id AND user_id = :userId FOR UPDATE",
                Map.of("id", playlistId, "userId", userId),
                (rs, rowNum) -> rs.getObject("playlist_id", UUID.class)).isEmpty();
    }

    public Optional<ContentType> findAvailableMediaType(UUID mediaId) {
        return jdbc.query(
                "SELECT media_type::text AS media_type FROM media WHERE media_id = :mediaId AND is_available = TRUE",
                Map.of("mediaId", mediaId),
                (rs, rowNum) -> ContentType.valueOf(rs.getString("media_type"))).stream().findFirst();
    }

    public Optional<PlaylistItemAddedResponse> findItem(UUID playlistId, UUID mediaId) {
        return jdbc.query("""
                SELECT playlist_item_id, media_id, position
                FROM playlist_items
                WHERE playlist_id = :playlistId AND media_id = :mediaId
                """, Map.of("playlistId", playlistId, "mediaId", mediaId), (rs, rowNum) ->
                new PlaylistItemAddedResponse(
                        rs.getObject("playlist_item_id", UUID.class),
                        rs.getObject("media_id", UUID.class),
                        rs.getInt("position"))).stream().findFirst();
    }

    public PlaylistItemAddedResponse insertItemAtEnd(UUID playlistId, UUID mediaId, Instant now) {
        Integer nextPos = jdbc.queryForObject(
                "SELECT COALESCE(MAX(position), -1) + 1 FROM playlist_items WHERE playlist_id = :playlistId",
                Map.of("playlistId", playlistId), Integer.class);
        int position = nextPos == null ? 0 : nextPos;
        UUID itemId = UUID.randomUUID();
        var params = new MapSqlParameterSource()
                .addValue("itemId", itemId)
                .addValue("playlistId", playlistId)
                .addValue("mediaId", mediaId)
                .addValue("position", position)
                .addValue("now", Timestamp.from(now));
        jdbc.update("""
                INSERT INTO playlist_items (playlist_item_id, playlist_id, media_id, position, skip_count, suggestion_dismissed, added_at)
                VALUES (:itemId, :playlistId, :mediaId, :position, 0, FALSE, :now)
                """, params);
        jdbc.update("UPDATE playlists SET updated_at = :now WHERE playlist_id = :playlistId",
                Map.of("now", Timestamp.from(now), "playlistId", playlistId));
        return new PlaylistItemAddedResponse(itemId, mediaId, position);
    }

    public void deleteItem(UUID playlistId, UUID mediaId, Instant now) {
        int removed = jdbc.update(
                "DELETE FROM playlist_items WHERE playlist_id = :playlistId AND media_id = :mediaId",
                Map.of("playlistId", playlistId, "mediaId", mediaId));
        if (removed > 0) {
            jdbc.update("UPDATE playlists SET updated_at = :now WHERE playlist_id = :playlistId",
                    Map.of("now", Timestamp.from(now), "playlistId", playlistId));
        }
    }

    public List<PlaylistDetailResponse.PlaylistItemResponse> findItems(UUID playlistId) {
        String sql = """
                SELECT pi.playlist_item_id, pi.media_id, m.title, pi.position, pi.skip_count, m.is_available AS available
                FROM playlist_items pi
                JOIN media m ON m.media_id = pi.media_id
                WHERE pi.playlist_id = :playlistId
                ORDER BY pi.position ASC, pi.playlist_item_id ASC
                """;
        return jdbc.query(sql, Map.of("playlistId", playlistId), (rs, rowNum) ->
                new PlaylistDetailResponse.PlaylistItemResponse(
                        rs.getObject("playlist_item_id", UUID.class),
                        rs.getObject("media_id", UUID.class),
                        rs.getString("title"),
                        rs.getInt("position"),
                        rs.getInt("skip_count"),
                        rs.getBoolean("available")));
    }

    public record PlaylistRow(
            UUID playlistId,
            UUID userId,
            String name,
            String creationName,
            int itemCount,
            Instant createdAt,
            Instant updatedAt) {
        public PlaylistSummaryResponse summary() {
            return new PlaylistSummaryResponse(playlistId, name, itemCount, createdAt, updatedAt);
        }
    }
}
