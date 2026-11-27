package com.omniplay.quest;

import com.omniplay.catalog.ContentType;
import com.omniplay.dto.response.ContentSummaryResponse;
import com.omniplay.dto.response.PageResponse;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class QuestRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public QuestRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public boolean lockUser(UUID userId) {
        return !jdbc.query(
                "SELECT user_id FROM users WHERE user_id = :userId FOR UPDATE",
                Map.of("userId", userId),
                (rs, rowNum) -> rs.getObject("user_id", UUID.class)).isEmpty();
    }

    public Optional<QuestSetRow> findQuestSet(UUID userId, LocalDate questDate) {
        String sql = """
                SELECT quest_set_id, user_id, quest_date, issued_at, expires_at
                FROM daily_quest_sets
                WHERE user_id = :userId AND quest_date = :questDate
                """;
        var params = new MapSqlParameterSource()
                .addValue("userId", userId)
                .addValue("questDate", Date.valueOf(questDate));
        return jdbc.query(sql, params, (rs, rowNum) -> new QuestSetRow(
                rs.getObject("quest_set_id", UUID.class),
                rs.getObject("user_id", UUID.class),
                rs.getDate("quest_date").toLocalDate(),
                rs.getTimestamp("issued_at").toInstant(),
                rs.getTimestamp("expires_at").toInstant())).stream().findFirst();
    }

    public List<DailyQuestRow> findQuestsBySet(UUID questSetId) {
        String sql = """
                SELECT dq.daily_quest_id, dq.quest_set_id, dq.user_id, qt.code, dq.title, dq.slot,
                       dq.source_scope::text AS source_scope, dq.media_type::text AS media_type,
                       qt.genre_id, dq.target_count, dq.progress_count, dq.status::text AS status,
                       dq.xp_reward
                FROM daily_quests dq
                JOIN quest_templates qt ON qt.template_id = dq.template_id
                WHERE dq.quest_set_id = :questSetId
                ORDER BY dq.slot ASC
                """;
        return jdbc.query(sql, Map.of("questSetId", questSetId), (rs, rowNum) -> readDailyQuestRow(rs));
    }

    public Optional<DailyQuestRow> findOwnedQuest(UUID userId, UUID questId) {
        String sql = """
                SELECT dq.daily_quest_id, dq.quest_set_id, dq.user_id, qt.code, dq.title, dq.slot,
                       dq.source_scope::text AS source_scope, dq.media_type::text AS media_type,
                       qt.genre_id, dq.target_count, dq.progress_count, dq.status::text AS status,
                       dq.xp_reward
                FROM daily_quests dq
                JOIN quest_templates qt ON qt.template_id = dq.template_id
                WHERE dq.daily_quest_id = :questId AND dq.user_id = :userId
                """;
        return jdbc.query(sql, Map.of("questId", questId, "userId", userId),
                (rs, rowNum) -> readDailyQuestRow(rs)).stream().findFirst();
    }

    public Map<UUID, List<UUID>> findEligibleMediaIdsByQuests(List<UUID> questIds) {
        if (questIds.isEmpty()) {
            return Map.of();
        }
        Map<UUID, List<UUID>> grouped = new HashMap<>();
        jdbc.query("""
                SELECT daily_quest_id, media_id
                FROM quest_eligible_media
                WHERE daily_quest_id IN (:questIds)
                ORDER BY daily_quest_id ASC, media_id ASC
                """, Map.of("questIds", questIds), rs -> {
            UUID questId = rs.getObject("daily_quest_id", UUID.class);
            UUID mediaId = rs.getObject("media_id", UUID.class);
            grouped.computeIfAbsent(questId, ignored -> new ArrayList<>()).add(mediaId);
        });
        return grouped;
    }

    public List<QuestTemplateRow> findActiveTemplates() {
        String sql = """
                SELECT template_id, code, title, media_type::text AS media_type, genre_id,
                       source_scope::text AS source_scope, is_fixed, target_count, xp_reward
                FROM quest_templates
                WHERE is_active = TRUE
                ORDER BY code ASC
                """;
        return jdbc.query(sql, (rs, rowNum) -> {
            String rawMediaType = rs.getString("media_type");
            return new QuestTemplateRow(
                    rs.getObject("template_id", UUID.class),
                    rs.getString("code"),
                    rs.getString("title"),
                    rawMediaType == null ? null : ContentType.valueOf(rawMediaType),
                    rs.getObject("genre_id", UUID.class),
                    rs.getString("source_scope"),
                    rs.getBoolean("is_fixed"),
                    rs.getInt("target_count"),
                    rs.getInt("xp_reward"));
        });
    }

    public int countAvailableMedia(ContentType mediaType, UUID genreId) {
        var params = new MapSqlParameterSource();
        StringBuilder sql = new StringBuilder("SELECT COUNT(*) FROM media m WHERE m.is_available = TRUE");
        if (mediaType != null) {
            sql.append(" AND m.media_type = CAST(:mediaType AS media_kind)");
            params.addValue("mediaType", mediaType.name());
        }
        if (genreId != null) {
            sql.append(" AND EXISTS (SELECT 1 FROM media_genres mg WHERE mg.media_id = m.media_id AND mg.genre_id = :genreId)");
            params.addValue("genreId", genreId);
        }
        Integer count = jdbc.queryForObject(sql.toString(), params, Integer.class);
        return count == null ? 0 : count;
    }

    public List<UUID> findAvailableSavedMediaIds(UUID userId, ContentType mediaType, UUID genreId) {
        var params = new MapSqlParameterSource("userId", userId);
        StringBuilder sql = new StringBuilder("""
                SELECT m.media_id
                FROM favorites f
                JOIN media m ON m.media_id = f.media_id
                WHERE f.user_id = :userId
                  AND m.is_available = TRUE
                """);
        if (mediaType != null) {
            sql.append(" AND m.media_type = CAST(:mediaType AS media_kind)");
            params.addValue("mediaType", mediaType.name());
        }
        if (genreId != null) {
            sql.append(" AND EXISTS (SELECT 1 FROM media_genres mg WHERE mg.media_id = m.media_id AND mg.genre_id = :genreId)");
            params.addValue("genreId", genreId);
        }
        sql.append(" ORDER BY m.media_id ASC");
        return jdbc.query(sql.toString(), params, (rs, rowNum) -> rs.getObject("media_id", UUID.class));
    }

    public UUID insertQuestSet(UUID userId, LocalDate questDate, Instant issuedAt, Instant expiresAt) {
        UUID questSetId = UUID.randomUUID();
        var params = new MapSqlParameterSource()
                .addValue("questSetId", questSetId)
                .addValue("userId", userId)
                .addValue("questDate", Date.valueOf(questDate))
                .addValue("issuedAt", Timestamp.from(issuedAt))
                .addValue("expiresAt", Timestamp.from(expiresAt));
        jdbc.update("""
                INSERT INTO daily_quest_sets (quest_set_id, user_id, quest_date, issued_at, expires_at)
                VALUES (:questSetId, :userId, :questDate, :issuedAt, :expiresAt)
                """, params);
        return questSetId;
    }

    public UUID insertDailyQuest(UUID questSetId, UUID userId, LocalDate questDate, int slot, QuestTemplateRow template) {
        UUID questId = UUID.randomUUID();
        var params = new MapSqlParameterSource()
                .addValue("questId", questId)
                .addValue("questSetId", questSetId)
                .addValue("userId", userId)
                .addValue("templateId", template.templateId())
                .addValue("questDate", Date.valueOf(questDate))
                .addValue("slot", slot)
                .addValue("title", template.title())
                .addValue("mediaType", template.mediaType() == null ? null : template.mediaType().name())
                .addValue("sourceScope", template.sourceScope())
                .addValue("targetCount", template.targetCount())
                .addValue("xpReward", template.xpReward());
        jdbc.update("""
                INSERT INTO daily_quests (
                    daily_quest_id, quest_set_id, user_id, template_id, quest_date, slot,
                    title, media_type, source_scope, target_count, xp_reward, progress_count, status
                )
                VALUES (
                    :questId, :questSetId, :userId, :templateId, :questDate, :slot,
                    :title, CAST(:mediaType AS media_kind), CAST(:sourceScope AS quest_scope),
                    :targetCount, :xpReward, 0, 'ACTIVE'
                )
                """, params);
        return questId;
    }

    public void insertEligibleMedia(UUID questId, List<UUID> mediaIds) {
        if (mediaIds.isEmpty()) {
            return;
        }
        MapSqlParameterSource[] batch = mediaIds.stream()
                .map(mediaId -> new MapSqlParameterSource()
                        .addValue("questId", questId)
                        .addValue("mediaId", mediaId))
                .toArray(MapSqlParameterSource[]::new);
        jdbc.batchUpdate("""
                INSERT INTO quest_eligible_media (daily_quest_id, media_id)
                VALUES (:questId, :mediaId)
                """, batch);
    }

    public PageResponse<ContentSummaryResponse> findQuestMediaPage(
            UUID userId, DailyQuestRow quest, int page, int size) {
        var params = new MapSqlParameterSource("userId", userId);
        String fromAndWhere;
        if ("SAVED".equals(quest.sourceScope())) {
            params.addValue("questId", quest.id());
            fromAndWhere = """
                    FROM quest_eligible_media qem
                    JOIN media m ON m.media_id = qem.media_id
                    LEFT JOIN favorites f ON f.media_id = m.media_id AND f.user_id = :userId
                    WHERE qem.daily_quest_id = :questId
                      AND m.is_available = TRUE
                    """;
        } else {
            StringBuilder sb = new StringBuilder("""
                    FROM media m
                    LEFT JOIN favorites f ON f.media_id = m.media_id AND f.user_id = :userId
                    WHERE m.is_available = TRUE
                    """);
            if (quest.mediaType() != null) {
                sb.append(" AND m.media_type = CAST(:mediaType AS media_kind)");
                params.addValue("mediaType", quest.mediaType().name());
            }
            if (quest.genreId() != null) {
                sb.append(" AND EXISTS (SELECT 1 FROM media_genres mg WHERE mg.media_id = m.media_id AND mg.genre_id = :genreId)");
                params.addValue("genreId", quest.genreId());
            }
            fromAndWhere = sb.toString();
        }

        Long total = jdbc.queryForObject("SELECT COUNT(*) " + fromAndWhere, params, Long.class);
        params.addValue("limit", size).addValue("offset", (long) page * size);

        String selectSql = """
                SELECT m.media_id AS id, m.media_type::text AS type, m.title, m.description,
                       CASE WHEN m.thumbnail_path IS NOT NULL AND btrim(m.thumbnail_path) <> ''
                            THEN '/media/' || m.media_id::text || '/thumbnail' ELSE NULL END AS thumbnail_url,
                       m.duration_seconds,
                       (f.media_id IS NOT NULL) AS saved
                """ + fromAndWhere + " ORDER BY m.created_at DESC, m.media_id ASC LIMIT :limit OFFSET :offset";

        var rows = jdbc.query(selectSql, params, (rs, rowNum) -> new MediaRow(
                rs.getObject("id", UUID.class),
                ContentType.valueOf(rs.getString("type")),
                rs.getString("title"),
                rs.getString("description"),
                rs.getString("thumbnail_url"),
                rs.getObject("duration_seconds", Integer.class),
                rs.getBoolean("saved")));

        var genresByMedia = loadGenres(rows.stream().map(MediaRow::id).toList());
        var items = rows.stream()
                .map(r -> new ContentSummaryResponse(
                        r.id(), r.type(), r.title(), r.description(), r.thumbnailUrl(),
                        r.durationSeconds(), genresByMedia.getOrDefault(r.id(), List.of()), r.saved()))
                .toList();
        return new PageResponse<>(items, page, size, total == null ? 0 : total);
    }

    private Map<UUID, List<UUID>> loadGenres(List<UUID> mediaIds) {
        if (mediaIds.isEmpty()) {
            return Map.of();
        }
        Map<UUID, List<UUID>> grouped = new HashMap<>();
        jdbc.query("""
                SELECT media_id, genre_id
                FROM media_genres
                WHERE media_id IN (:mediaIds)
                ORDER BY media_id ASC, genre_id ASC
                """, Map.of("mediaIds", mediaIds), rs -> {
            UUID mediaId = rs.getObject("media_id", UUID.class);
            UUID genreId = rs.getObject("genre_id", UUID.class);
            grouped.computeIfAbsent(mediaId, ignored -> new ArrayList<>()).add(genreId);
        });
        return grouped;
    }

    private DailyQuestRow readDailyQuestRow(ResultSet rs) throws SQLException {
        String rawMediaType = rs.getString("media_type");
        return new DailyQuestRow(
                rs.getObject("daily_quest_id", UUID.class),
                rs.getObject("quest_set_id", UUID.class),
                rs.getObject("user_id", UUID.class),
                rs.getString("code"),
                rs.getString("title"),
                rs.getInt("slot"),
                rs.getString("source_scope"),
                rawMediaType == null ? null : ContentType.valueOf(rawMediaType),
                rs.getObject("genre_id", UUID.class),
                rs.getInt("target_count"),
                rs.getInt("progress_count"),
                rs.getString("status"),
                rs.getInt("xp_reward"));
    }

    public record QuestSetRow(
            UUID questSetId,
            UUID userId,
            LocalDate questDate,
            Instant issuedAt,
            Instant expiresAt) {}

    public record DailyQuestRow(
            UUID id,
            UUID questSetId,
            UUID userId,
            String code,
            String title,
            int slot,
            String sourceScope,
            ContentType mediaType,
            UUID genreId,
            int targetCount,
            int progressCount,
            String status,
            int xpReward) {}

    public record QuestTemplateRow(
            UUID templateId,
            String code,
            String title,
            ContentType mediaType,
            UUID genreId,
            String sourceScope,
            boolean fixed,
            int targetCount,
            int xpReward) {}

    private record MediaRow(
            UUID id,
            ContentType type,
            String title,
            String description,
            String thumbnailUrl,
            Integer durationSeconds,
            boolean saved) {}
}
