package com.omniplay.quest;

import com.omniplay.catalog.ContentType;
import com.omniplay.playback.PlaybackSegmentMerger;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class QuestProgressRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public QuestProgressRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<QuestSetWindow> findOwnedQuestSet(UUID userId, UUID questSetId) {
        String sql = """
                SELECT quest_set_id, issued_at, expires_at
                FROM daily_quest_sets
                WHERE quest_set_id = :questSetId
                  AND user_id = :userId
                """;
        return jdbc.query(sql, Map.of("questSetId", questSetId, "userId", userId),
                (rs, rowNum) -> new QuestSetWindow(
                        rs.getObject("quest_set_id", UUID.class),
                        rs.getTimestamp("issued_at").toInstant().truncatedTo(ChronoUnit.MICROS),
                        rs.getTimestamp("expires_at").toInstant().truncatedTo(ChronoUnit.MICROS)))
                .stream().findFirst();
    }

    public List<PlaybackSegmentMerger.Interval> findEligibleQuestIntervals(
            UUID progressId, UUID questSetId, Instant issuedAt, Instant expiresAt) {
        var params = new MapSqlParameterSource()
                .addValue("progressId", progressId)
                .addValue("questSetId", questSetId)
                .addValue("issuedAt", Timestamp.from(issuedAt))
                .addValue("expiresAt", Timestamp.from(expiresAt));
        String sql = """
                SELECT start_second, end_second
                FROM playback_segments
                WHERE progress_id = :progressId
                  AND quest_set_id = :questSetId
                  AND played_from >= :issuedAt
                  AND received_at < :expiresAt
                """;
        return jdbc.query(sql, params, (rs, rowNum) -> new PlaybackSegmentMerger.Interval(
                rs.getBigDecimal("start_second"),
                rs.getBigDecimal("end_second")));
    }

    public Optional<MediaProfile> findMediaProfile(UUID mediaId) {
        var mediaTypeOpt = jdbc.query(
                "SELECT media_type::text AS media_type FROM media WHERE media_id = :mediaId",
                Map.of("mediaId", mediaId),
                (rs, rowNum) -> ContentType.valueOf(rs.getString("media_type"))).stream().findFirst();
        if (mediaTypeOpt.isEmpty()) {
            return Optional.empty();
        }
        Set<UUID> genreIds = new HashSet<>(jdbc.query(
                "SELECT genre_id FROM media_genres WHERE media_id = :mediaId",
                Map.of("mediaId", mediaId),
                (rs, rowNum) -> rs.getObject("genre_id", UUID.class)));
        return Optional.of(new MediaProfile(mediaTypeOpt.get(), Set.copyOf(genreIds)));
    }

    public List<LockedQuest> lockQuestsBySet(UUID questSetId) {
        String sql = """
                SELECT dq.daily_quest_id, dq.slot, dq.source_scope::text AS source_scope,
                       dq.media_type::text AS media_type, qt.genre_id,
                       dq.target_count, dq.progress_count, dq.status::text AS status
                FROM daily_quests dq
                JOIN quest_templates qt ON qt.template_id = dq.template_id
                WHERE dq.quest_set_id = :questSetId
                ORDER BY dq.slot ASC
                FOR UPDATE OF dq
                """;
        return jdbc.query(sql, Map.of("questSetId", questSetId), (rs, rowNum) -> {
            String rawMediaType = rs.getString("media_type");
            return new LockedQuest(
                    rs.getObject("daily_quest_id", UUID.class),
                    rs.getInt("slot"),
                    rs.getString("source_scope"),
                    rawMediaType == null ? null : ContentType.valueOf(rawMediaType),
                    rs.getObject("genre_id", UUID.class),
                    rs.getInt("target_count"),
                    rs.getInt("progress_count"),
                    rs.getString("status"));
        });
    }

    public Set<UUID> findEligibleSavedQuestIdsForMedia(List<UUID> savedQuestIds, UUID mediaId) {
        if (savedQuestIds.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(jdbc.query("""
                SELECT daily_quest_id
                FROM quest_eligible_media
                WHERE daily_quest_id IN (:questIds)
                  AND media_id = :mediaId
                """, Map.of("questIds", savedQuestIds, "mediaId", mediaId),
                (rs, rowNum) -> rs.getObject("daily_quest_id", UUID.class)));
    }

    public boolean insertQuestMediaCredit(UUID questId, UUID mediaId, Instant creditedAt) {
        var params = new MapSqlParameterSource()
                .addValue("questId", questId)
                .addValue("mediaId", mediaId)
                .addValue("creditedAt", Timestamp.from(creditedAt));
        int inserted = jdbc.update("""
                INSERT INTO quest_media_credits (daily_quest_id, media_id, credited_at)
                VALUES (:questId, :mediaId, :creditedAt)
                ON CONFLICT (daily_quest_id, media_id) DO NOTHING
                """, params);
        return inserted > 0;
    }

    public void updateQuestProgress(UUID questId, int progressCount, String status) {
        var params = new MapSqlParameterSource()
                .addValue("questId", questId)
                .addValue("progressCount", progressCount)
                .addValue("status", status);
        jdbc.update("""
                UPDATE daily_quests
                SET progress_count = :progressCount,
                    status = CAST(:status AS quest_status)
                WHERE daily_quest_id = :questId
                """, params);
    }

    public record QuestSetWindow(UUID questSetId, Instant issuedAt, Instant expiresAt) {}

    public record MediaProfile(ContentType mediaType, Set<UUID> genreIds) {}

    public record LockedQuest(
            UUID id,
            int slot,
            String sourceScope,
            ContentType mediaType,
            UUID genreId,
            int targetCount,
            int progressCount,
            String status) {}
}
