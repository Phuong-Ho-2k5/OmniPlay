package com.omniplay.playback;

import com.omniplay.catalog.ContentType;
import com.omniplay.dto.response.PlaybackMetadataResponse;
import java.math.BigDecimal;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class PlaybackQueryRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public PlaybackQueryRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<PlaybackMetadataResponse> findPlaybackMetadata(UUID userId, UUID mediaId) {
        String sql = """
                SELECT m.media_id, m.media_type::text AS type, m.duration_seconds,
                       COALESCE(pp.resume_position_seconds, 0) AS resume_position_seconds,
                       COALESCE(pp.completed, FALSE) AS completed
                FROM media m
                LEFT JOIN playback_progress pp
                  ON pp.media_id = m.media_id AND pp.user_id = :userId
                WHERE m.media_id = :mediaId AND m.is_available = TRUE
                """;
        return jdbc.query(sql, Map.of("userId", userId, "mediaId", mediaId), (rs, rowNum) -> {
            UUID id = rs.getObject("media_id", UUID.class);
            BigDecimal resume = rs.getBigDecimal("resume_position_seconds");
            return new PlaybackMetadataResponse(
                    id,
                    ContentType.valueOf(rs.getString("type")),
                    rs.getInt("duration_seconds"),
                    resume == null ? BigDecimal.ZERO : resume.stripTrailingZeros(),
                    rs.getBoolean("completed"),
                    "/media/" + id + "/stream");
        }).stream().findFirst();
    }

    public Optional<AvailableMediaFile> findAvailableMediaFile(UUID mediaId) {
        String sql = """
                SELECT m.media_type::text AS type, m.file_path
                FROM media m
                WHERE m.media_id = :mediaId AND m.is_available = TRUE
                """;
        return jdbc.query(sql, Map.of("mediaId", mediaId), (rs, rowNum) ->
                new AvailableMediaFile(ContentType.valueOf(rs.getString("type")), rs.getString("file_path")))
                .stream().findFirst();
    }

    public record AvailableMediaFile(ContentType type, String filePath) {}
}
