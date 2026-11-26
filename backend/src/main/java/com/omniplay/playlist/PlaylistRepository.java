package com.omniplay.playlist;

import com.omniplay.dto.response.PageResponse;
import com.omniplay.dto.response.PlaylistDetailResponse;
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
