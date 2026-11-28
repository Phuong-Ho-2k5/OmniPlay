package com.omniplay.quest;

import com.omniplay.dto.response.QuestClaimResponse.BadgeAwardResponse;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class QuestClaimRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public QuestClaimRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<LockedUserRewards> lockUserRewards(UUID userId) {
        String sql = """
                SELECT user_id, total_xp, level
                FROM users
                WHERE user_id = :userId
                FOR UPDATE
                """;
        return jdbc.query(sql, Map.of("userId", userId), (rs, rowNum) -> new LockedUserRewards(
                rs.getObject("user_id", UUID.class),
                rs.getInt("total_xp"),
                rs.getInt("level"))).stream().findFirst();
    }

    public Optional<LockedClaimQuest> lockOwnedQuest(UUID userId, UUID questId) {
        String sql = """
                SELECT dq.daily_quest_id, dq.status::text AS status, dq.xp_reward, dqs.expires_at
                FROM daily_quests dq
                JOIN daily_quest_sets dqs ON dqs.quest_set_id = dq.quest_set_id
                WHERE dq.daily_quest_id = :questId
                  AND dq.user_id = :userId
                FOR UPDATE OF dq
                """;
        return jdbc.query(sql, Map.of("questId", questId, "userId", userId), (rs, rowNum) -> new LockedClaimQuest(
                rs.getObject("daily_quest_id", UUID.class),
                rs.getString("status"),
                rs.getInt("xp_reward"),
                rs.getTimestamp("expires_at").toInstant().truncatedTo(ChronoUnit.MICROS))).stream().findFirst();
    }

    public void markClaimed(UUID questId, Instant claimedAt) {
        var params = new MapSqlParameterSource()
                .addValue("questId", questId)
                .addValue("claimedAt", Timestamp.from(claimedAt));
        jdbc.update("""
                UPDATE daily_quests
                SET status = CAST('CLAIMED' AS quest_status),
                    claimed_at = :claimedAt
                WHERE daily_quest_id = :questId
                """, params);
    }

    public void updateUserXpAndLevel(UUID userId, int totalXp, int level) {
        var params = new MapSqlParameterSource()
                .addValue("userId", userId)
                .addValue("totalXp", totalXp)
                .addValue("level", level);
        jdbc.update("""
                UPDATE users
                SET total_xp = :totalXp,
                    level = :level
                WHERE user_id = :userId
                """, params);
    }

    public List<BadgeAwardResponse> unlockEligibleBadges(UUID userId, int totalXp, Instant awardedAt) {
        String sql = """
                SELECT b.badge_id, b.name, b.description, b.xp_threshold
                FROM badges b
                WHERE b.xp_threshold <= :totalXp
                  AND NOT EXISTS (
                      SELECT 1
                      FROM user_badges ub
                      WHERE ub.user_id = :userId
                        AND ub.badge_id = b.badge_id
                  )
                ORDER BY b.xp_threshold ASC
                """;
        List<BadgeRow> candidates = jdbc.query(sql, Map.of("totalXp", totalXp, "userId", userId),
                (rs, rowNum) -> new BadgeRow(
                        rs.getObject("badge_id", UUID.class),
                        rs.getString("name"),
                        rs.getString("description"),
                        rs.getInt("xp_threshold")));

        List<BadgeAwardResponse> unlocked = new ArrayList<>();
        for (BadgeRow badge : candidates) {
            var params = new MapSqlParameterSource()
                    .addValue("userId", userId)
                    .addValue("badgeId", badge.id())
                    .addValue("awardedAt", Timestamp.from(awardedAt));
            int inserted = jdbc.update("""
                    INSERT INTO user_badges (user_id, badge_id, awarded_at)
                    VALUES (:userId, :badgeId, :awardedAt)
                    ON CONFLICT (user_id, badge_id) DO NOTHING
                    """, params);
            if (inserted > 0) {
                unlocked.add(new BadgeAwardResponse(
                        badge.id(),
                        badge.name(),
                        badge.description(),
                        badge.xpThreshold(),
                        awardedAt));
            }
        }
        return unlocked;
    }

    public record LockedUserRewards(UUID userId, int totalXp, int level) {}

    public record LockedClaimQuest(UUID questId, String status, int xpReward, Instant expiresAt) {}

    private record BadgeRow(UUID id, String name, String description, int xpThreshold) {}
}
