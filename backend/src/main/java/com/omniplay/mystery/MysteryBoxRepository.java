package com.omniplay.mystery;

import com.omniplay.catalog.ContentType;
import com.omniplay.dto.response.ContentSummaryResponse;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class MysteryBoxRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public MysteryBoxRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<UUID> findMatchingAvailableMediaIds(
            ContentType mediaType,
            UUID genreId,
            Integer maxDurationSeconds) {
        var params = new MapSqlParameterSource();
        StringBuilder sql = new StringBuilder("""
                SELECT m.media_id
                FROM media m
                WHERE m.is_available = TRUE
                """);
        if (mediaType != null) {
            sql.append(" AND m.media_type = CAST(:mediaType AS media_kind)");
            params.addValue("mediaType", mediaType.name());
        }
        if (genreId != null) {
            sql.append("""
                     AND EXISTS (
                        SELECT 1 FROM media_genres mg
                        WHERE mg.media_id = m.media_id AND mg.genre_id = :genreId
                    )
                    """);
            params.addValue("genreId", genreId);
        }
        if (maxDurationSeconds != null) {
            sql.append(" AND m.duration_seconds <= :maxDurationSeconds");
            params.addValue("maxDurationSeconds", maxDurationSeconds);
        }
        sql.append(" ORDER BY m.media_id ASC");
        return jdbc.query(sql.toString(), params, (rs, rowNum) -> rs.getObject("media_id", UUID.class));
    }

    public Optional<ContentSummaryResponse> findMediaSummary(UUID userId, UUID mediaId) {
        String sql = """
                SELECT m.media_id AS id, m.media_type::text AS type, m.title, m.description,
                       CASE WHEN m.thumbnail_path IS NOT NULL AND btrim(m.thumbnail_path) <> ''
                            THEN '/media/' || m.media_id::text || '/thumbnail' ELSE NULL END AS thumbnail_url,
                       m.duration_seconds,
                       (f.media_id IS NOT NULL) AS saved
                FROM media m
                LEFT JOIN favorites f ON f.media_id = m.media_id AND f.user_id = :userId
                WHERE m.media_id = :mediaId
                  AND m.is_available = TRUE
                """;
        var rowOpt = jdbc.query(sql, Map.of("userId", userId, "mediaId", mediaId), (rs, rowNum) -> new MediaRow(
                rs.getObject("id", UUID.class),
                ContentType.valueOf(rs.getString("type")),
                rs.getString("title"),
                rs.getString("description"),
                rs.getString("thumbnail_url"),
                rs.getObject("duration_seconds", Integer.class),
                rs.getBoolean("saved"))).stream().findFirst();
        if (rowOpt.isEmpty()) {
            return Optional.empty();
        }
        List<UUID> genreIds = jdbc.query(
                "SELECT genre_id FROM media_genres WHERE media_id = :mediaId ORDER BY genre_id ASC",
                Map.of("mediaId", mediaId),
                (rs, rowNum) -> rs.getObject("genre_id", UUID.class));
        MediaRow row = rowOpt.get();
        return Optional.of(new ContentSummaryResponse(
                row.id(),
                row.type(),
                row.title(),
                row.description(),
                row.thumbnailUrl(),
                row.durationSeconds(),
                genreIds,
                row.saved()));
    }

    private record MediaRow(
            UUID id,
            ContentType type,
            String title,
            String description,
            String thumbnailUrl,
            Integer durationSeconds,
            boolean saved) {}
}
