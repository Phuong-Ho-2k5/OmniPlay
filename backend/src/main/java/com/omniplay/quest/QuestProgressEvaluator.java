package com.omniplay.quest;

import com.omniplay.dto.response.PlaybackProgressResponse.QuestUpdate;
import com.omniplay.playback.PlaybackSegmentMerger;
import com.omniplay.quest.QuestProgressRepository.LockedQuest;
import com.omniplay.quest.QuestProgressRepository.MediaProfile;
import com.omniplay.quest.QuestProgressRepository.QuestSetWindow;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class QuestProgressEvaluator {
    private final QuestProgressRepository repository;

    public QuestProgressEvaluator(QuestProgressRepository repository) {
        this.repository = repository;
    }

    public List<QuestUpdate> evaluate(
            UUID mediaId,
            UUID progressId,
            int durationSeconds,
            QuestSetWindow questSet,
            Instant receivedAt) {
        if (!receivedAt.isBefore(questSet.expiresAt())) {
            return List.of();
        }

        var intervals = repository.findEligibleQuestIntervals(
                progressId, questSet.questSetId(), questSet.issuedAt(), questSet.expiresAt());
        if (intervals.isEmpty()) {
            return List.of();
        }

        BigDecimal questCovered = PlaybackSegmentMerger.mergeTotalSeconds(intervals);
        if (!PlaybackSegmentMerger.isCompleted(questCovered, durationSeconds)) {
            return List.of();
        }

        MediaProfile media = repository.findMediaProfile(mediaId).orElse(null);
        if (media == null) {
            return List.of();
        }

        List<LockedQuest> lockedQuests = repository.lockQuestsBySet(questSet.questSetId());
        List<UUID> activeSavedQuestIds = lockedQuests.stream()
                .filter(q -> "ACTIVE".equals(q.status()) && "SAVED".equals(q.sourceScope()))
                .map(LockedQuest::id)
                .toList();
        Set<UUID> eligibleSavedQuestIds = repository.findEligibleSavedQuestIdsForMedia(activeSavedQuestIds, mediaId);

        List<QuestUpdate> updates = new ArrayList<>();
        for (LockedQuest quest : lockedQuests) {
            if (!"ACTIVE".equals(quest.status())) {
                continue;
            }
            if (!matchesQuest(quest, media, eligibleSavedQuestIds)) {
                continue;
            }
            if (!repository.insertQuestMediaCredit(quest.id(), mediaId, receivedAt)) {
                continue;
            }
            int nextProgress = Math.min(quest.targetCount(), quest.progressCount() + 1);
            String nextStatus = nextProgress >= quest.targetCount() ? "CLAIMABLE" : "ACTIVE";
            repository.updateQuestProgress(quest.id(), nextProgress, nextStatus);
            updates.add(new QuestUpdate(quest.id(), nextProgress, nextStatus));
        }
        return updates;
    }

    private boolean matchesQuest(LockedQuest quest, MediaProfile media, Set<UUID> eligibleSavedQuestIds) {
        if ("SAVED".equals(quest.sourceScope())) {
            return eligibleSavedQuestIds.contains(quest.id());
        }
        if (quest.mediaType() != null && quest.mediaType() != media.mediaType()) {
            return false;
        }
        return quest.genreId() == null || media.genreIds().contains(quest.genreId());
    }
}
