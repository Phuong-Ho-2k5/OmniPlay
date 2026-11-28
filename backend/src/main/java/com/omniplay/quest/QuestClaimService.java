package com.omniplay.quest;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.response.QuestClaimResponse;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class QuestClaimService {
    private final QuestClaimRepository repository;
    private final Clock clock;

    public QuestClaimService(QuestClaimRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional
    public QuestClaimResponse claim(UUID userId, UUID questId) {
        Instant now = clock.instant().truncatedTo(ChronoUnit.MICROS);

        // Canonical lock order: users -> daily_quests
        var user = repository.lockUserRewards(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        var quest = repository.lockOwnedQuest(userId, questId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));

        if ("CLAIMED".equals(quest.status())) {
            return new QuestClaimResponse(
                    quest.questId(),
                    "CLAIMED",
                    0,
                    user.totalXp(),
                    user.level(),
                    List.of());
        }

        if ("EXPIRED".equals(quest.status()) || !now.isBefore(quest.expiresAt())) {
            throw new ApiException(ErrorCode.QUEST_EXPIRED);
        }

        if (!"CLAIMABLE".equals(quest.status())) {
            throw new ApiException(ErrorCode.QUEST_NOT_COMPLETED);
        }

        repository.markClaimed(quest.questId(), now);

        int xpAwarded = quest.xpReward();
        int newTotalXp = user.totalXp() + xpAwarded;
        int newLevel = 1 + (newTotalXp / 100);
        repository.updateUserXpAndLevel(userId, newTotalXp, newLevel);

        var newBadges = repository.unlockEligibleBadges(userId, newTotalXp, now);

        return new QuestClaimResponse(
                quest.questId(),
                "CLAIMED",
                xpAwarded,
                newTotalXp,
                newLevel,
                newBadges);
    }
}
