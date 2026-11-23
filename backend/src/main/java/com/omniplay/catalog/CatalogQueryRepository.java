package com.omniplay.catalog;

import com.omniplay.dto.response.*;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.*;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class CatalogQueryRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public CatalogQueryRepository(NamedParameterJdbcTemplate jdbc) { this.jdbc = jdbc; }

    // Fixed SQL fragments only; every request value is a bound parameter.
    private String source(CatalogQuery query, MapSqlParameterSource parameters, boolean detail) {
        String mediaWhere = "m.is_available = TRUE";
        String postWhere = "p.is_available = TRUE";
        if (query.type() != null) {
            parameters.addValue("type", query.type().name());
            mediaWhere += " AND m.media_type::text = :type";
            if (query.type() != ContentType.POST) postWhere += " AND FALSE";
        }
        if (query.genreId() != null) {
            parameters.addValue("genreId", query.genreId());
            mediaWhere += " AND EXISTS (SELECT 1 FROM media_genres mg WHERE mg.media_id = m.media_id AND mg.genre_id = :genreId)";
            postWhere += " AND FALSE";
        }
        if (!query.q().isEmpty()) {
            parameters.addValue("pattern", "%" + query.q().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%");
            mediaWhere += " AND m.title ILIKE :pattern ESCAPE E'\\\\'";
            postWhere += " AND p.title ILIKE :pattern ESCAPE E'\\\\'";
        }
        if (detail) {
            mediaWhere += " AND m.media_id = :id";
            postWhere += " AND p.post_id = :id";
        }
        return """
                SELECT m.media_id AS id, m.media_type::text AS type, m.title, m.description,
                       CASE WHEN m.thumbnail_path IS NOT NULL AND btrim(m.thumbnail_path) <> ''
                            THEN '/media/' || m.media_id::text || '/thumbnail' ELSE NULL END AS thumbnail_url,
                       m.duration_seconds, m.created_at,
                       EXISTS (SELECT 1 FROM favorites f WHERE f.media_id = m.media_id AND f.user_id = :userId) AS saved,
                       NULL::text AS content
                FROM media m WHERE %s
                UNION ALL
                SELECT p.post_id AS id, 'POST'::text AS type, p.title, left(p.content, 160) AS description,
                       NULL::text AS thumbnail_url, NULL::integer AS duration_seconds, p.created_at,
                       EXISTS (SELECT 1 FROM post_favorites f WHERE f.post_id = p.post_id AND f.user_id = :userId) AS saved,
                       %s AS content
                FROM posts p WHERE %s
                """.formatted(mediaWhere, detail ? "p.content" : "NULL::text", postWhere);
    }

    public PageResponse<ContentSummaryResponse> findPage(UUID userId, CatalogQuery query) {
        var parameters = new MapSqlParameterSource("userId", userId);
        String source = source(query, parameters, false);
        Long total = jdbc.queryForObject("SELECT count(*) FROM (" + source + ") catalog", parameters, Long.class);
        parameters.addValue("limit", query.size()).addValue("offset", (long) query.page() * query.size());
        var rows = jdbc.query("SELECT * FROM (" + source + ") catalog ORDER BY created_at DESC, id DESC, type ASC LIMIT :limit OFFSET :offset",
                parameters, (rs, row) -> readRow(rs));
        Map<UUID, List<UUID>> genres = genreIds(rows);
        var items = rows.stream().map(row -> row.summary(genres.getOrDefault(row.id(), List.of()))).toList();
        return new PageResponse<>(items, query.page(), query.size(), total == null ? 0 : total);
    }

    public Optional<ContentDetailResponse> findDetail(UUID userId, UUID id, ContentType type) {
        var parameters = new MapSqlParameterSource("userId", userId).addValue("id", id);
        String source = source(new CatalogQuery("", type, null, 0, 1), parameters, true);
        var rows = jdbc.query("SELECT * FROM (" + source + ") catalog", parameters, (rs, row) -> readRow(rs));
        if (rows.isEmpty()) return Optional.empty();
        Row row = rows.getFirst();
        var genres = genreIds(rows).getOrDefault(id, List.of());
        return Optional.of(new ContentDetailResponse(row.id(), row.type(), row.title(), row.description(),
                row.thumbnailUrl(), row.durationSeconds(), genres, row.saved(), row.content()));
    }

    public List<GenreResponse> findGenres() {
        return jdbc.query("SELECT genre_id, name FROM genres ORDER BY name ASC, genre_id ASC",
                (rs, row) -> new GenreResponse(rs.getObject("genre_id", UUID.class), rs.getString("name")));
    }

    public Optional<String> findAvailableThumbnailPath(UUID mediaId) {
        return jdbc.query("SELECT thumbnail_path FROM media WHERE media_id = :id AND is_available = TRUE AND thumbnail_path IS NOT NULL",
                Map.of("id", mediaId), (rs, row) -> rs.getString("thumbnail_path")).stream().findFirst();
    }

    private Map<UUID, List<UUID>> genreIds(List<Row> rows) {
        var ids = rows.stream().filter(row -> row.type() != ContentType.POST).map(Row::id).toList();
        Map<UUID, List<UUID>> result = new HashMap<>();
        if (!ids.isEmpty()) {
            jdbc.query("SELECT media_id, genre_id FROM media_genres WHERE media_id IN (:ids) ORDER BY genre_id ASC",
                    Map.of("ids", ids), (org.springframework.jdbc.core.RowCallbackHandler) rs ->
                            result.computeIfAbsent(rs.getObject("media_id", UUID.class), key -> new ArrayList<>())
                                    .add(rs.getObject("genre_id", UUID.class)));
        }
        return result;
    }

    private Row readRow(ResultSet rs) throws SQLException {
        return new Row(rs.getObject("id", UUID.class), ContentType.valueOf(rs.getString("type")),
                rs.getString("title"), rs.getString("description"), rs.getString("thumbnail_url"),
                rs.getObject("duration_seconds", Integer.class), rs.getBoolean("saved"), rs.getString("content"));
    }

    private record Row(UUID id, ContentType type, String title, String description, String thumbnailUrl,
                       Integer durationSeconds, boolean saved, String content) {
        ContentSummaryResponse summary(List<UUID> genres) {
            return new ContentSummaryResponse(id, type, title, description, thumbnailUrl, durationSeconds,
                    type == ContentType.POST ? List.of() : genres, saved);
        }
    }
}
