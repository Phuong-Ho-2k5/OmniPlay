package com.omniplay.saved;

import com.omniplay.catalog.ContentType;
import com.omniplay.dto.response.PageResponse;
import com.omniplay.dto.response.SavedContentSummaryResponse;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.RowCallbackHandler;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class SavedRepository {
    private static final String SAVED_UNION_SQL = """
            SELECT m.media_id AS id, m.media_type::text AS type, m.title, m.description,
                   CASE WHEN m.is_available = TRUE AND m.thumbnail_path IS NOT NULL AND btrim(m.thumbnail_path) <> ''
                        THEN '/media/' || m.media_id::text || '/thumbnail' ELSE NULL END AS thumbnail_url,
                   m.duration_seconds, m.is_available AS available, f.saved_at
            FROM favorites f
            JOIN media m ON m.media_id = f.media_id
            WHERE f.user_id = :userId
            UNION ALL
            SELECT p.post_id AS id, 'POST'::text AS type, p.title, left(p.content, 160) AS description,
                   NULL::text AS thumbnail_url, NULL::integer AS duration_seconds, p.is_available AS available, pf.saved_at
            FROM post_favorites pf
            JOIN posts p ON p.post_id = pf.post_id
            WHERE pf.user_id = :userId
            """;

    private final NamedParameterJdbcTemplate jdbc;

    public SavedRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public PageResponse<SavedContentSummaryResponse> findSavedPage(UUID userId, int page, int size) {
        var params = new MapSqlParameterSource("userId", userId);
        Long total = jdbc.queryForObject(
                "SELECT count(*) FROM (" + SAVED_UNION_SQL + ") saved_items", params, Long.class);
        params.addValue("limit", size).addValue("offset", (long) page * size);
        var rows = jdbc.query(
                "SELECT * FROM (" + SAVED_UNION_SQL + ") saved_items ORDER BY saved_at DESC, type ASC, id ASC LIMIT :limit OFFSET :offset",
                params, (rs, rowNum) -> readRow(rs));
        var genres = loadGenres(rows);
        var items = rows.stream()
                .map(row -> new SavedContentSummaryResponse(
                        row.id(), row.type(), row.title(), row.description(), row.thumbnailUrl(),
                        row.durationSeconds(),
                        row.type() == ContentType.POST ? List.of() : genres.getOrDefault(row.id(), List.of()),
                        true, row.available(), row.savedAt()))
                .toList();
        return new PageResponse<>(items, page, size, total == null ? 0 : total);
    }

    public boolean isMediaAvailableWithType(UUID mediaId, ContentType type) {
        return !jdbc.query(
                "SELECT 1 FROM media WHERE media_id = :id AND media_type::text = :type AND is_available = TRUE",
                Map.of("id", mediaId, "type", type.name()),
                (rs, rowNum) -> 1).isEmpty();
    }

    public boolean isPostAvailable(UUID postId) {
        return !jdbc.query(
                "SELECT 1 FROM posts WHERE post_id = :id AND is_available = TRUE",
                Map.of("id", postId),
                (rs, rowNum) -> 1).isEmpty();
    }

    public void saveMedia(UUID userId, UUID mediaId) {
        jdbc.update("""
                INSERT INTO favorites (user_id, media_id)
                VALUES (:userId, :mediaId)
                ON CONFLICT (user_id, media_id) DO NOTHING
                """, Map.of("userId", userId, "mediaId", mediaId));
    }

    public void unsaveMedia(UUID userId, UUID mediaId) {
        jdbc.update("DELETE FROM favorites WHERE user_id = :userId AND media_id = :mediaId",
                Map.of("userId", userId, "mediaId", mediaId));
    }

    public void savePost(UUID userId, UUID postId) {
        jdbc.update("""
                INSERT INTO post_favorites (user_id, post_id)
                VALUES (:userId, :postId)
                ON CONFLICT (user_id, post_id) DO NOTHING
                """, Map.of("userId", userId, "postId", postId));
    }

    public void unsavePost(UUID userId, UUID postId) {
        jdbc.update("DELETE FROM post_favorites WHERE user_id = :userId AND post_id = :postId",
                Map.of("userId", userId, "postId", postId));
    }

    private Map<UUID, List<UUID>> loadGenres(List<Row> rows) {
        var ids = rows.stream().filter(r -> r.type() != ContentType.POST).map(Row::id).toList();
        Map<UUID, List<UUID>> result = new HashMap<>();
        if (!ids.isEmpty()) {
            jdbc.query("SELECT media_id, genre_id FROM media_genres WHERE media_id IN (:ids) ORDER BY genre_id ASC",
                    Map.of("ids", ids), (RowCallbackHandler) rs ->
                            result.computeIfAbsent(rs.getObject("media_id", UUID.class), k -> new ArrayList<>())
                                    .add(rs.getObject("genre_id", UUID.class)));
        }
        return result;
    }

    private Row readRow(ResultSet rs) throws SQLException {
        return new Row(
                rs.getObject("id", UUID.class),
                ContentType.valueOf(rs.getString("type")),
                rs.getString("title"),
                rs.getString("description"),
                rs.getString("thumbnail_url"),
                rs.getObject("duration_seconds", Integer.class),
                rs.getBoolean("available"),
                rs.getTimestamp("saved_at").toInstant());
    }

    private record Row(
            UUID id,
            ContentType type,
            String title,
            String description,
            String thumbnailUrl,
            Integer durationSeconds,
            boolean available,
            Instant savedAt) {}
}
