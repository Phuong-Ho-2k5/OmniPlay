package com.omniplay.quest;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.response.ContentSummaryResponse;
import com.omniplay.dto.response.DailyQuestSetResponse;
import com.omniplay.dto.response.DailyQuestSetResponse.DailyQuestItemResponse;
import com.omniplay.dto.response.PageResponse;
import com.omniplay.quest.QuestRepository.DailyQuestRow;
import com.omniplay.quest.QuestRepository.QuestSetRow;
import com.omniplay.quest.QuestRepository.QuestTemplateRow;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class QuestService {
    public static final ZoneId QUEST_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    private final QuestRepository repository;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public QuestService(QuestRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional
    public DailyQuestSetResponse ensureToday(UUID userId) {
        Instant issuedAt = clock.instant().truncatedTo(ChronoUnit.MICROS);
        LocalDate questDate = issuedAt.atZone(QUEST_ZONE).toLocalDate();
        Instant expiresAt = questDate.plusDays(1).atStartOfDay(QUEST_ZONE).toInstant();

        if (!repository.lockUser(userId)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }

        var existing = repository.findQuestSet(userId, questDate);
        if (existing.isPresent()) {
            return buildResponse(existing.get());
        }

        List<QuestTemplateRow> activeTemplates = repository.findActiveTemplates();
        QuestTemplateRow q01 = findByCode(activeTemplates, "Q01");
        QuestTemplateRow q02 = findByCode(activeTemplates, "Q02");
        if (q01 == null || q02 == null || !q01.fixed() || !q02.fixed()) {
            throw new ApiException(ErrorCode.QUEST_CONFIGURATION_INVALID);
        }

        EligibleCandidate slot1 = evaluateCandidate(userId, q01);
        EligibleCandidate slot2 = evaluateCandidate(userId, q02);
        if (slot1 == null || slot2 == null) {
            throw new ApiException(ErrorCode.QUEST_CONFIGURATION_INVALID);
        }

        List<EligibleCandidate> randomPool = new ArrayList<>();
        for (QuestTemplateRow tpl : activeTemplates) {
            if (tpl.fixed()) {
                continue;
            }
            EligibleCandidate candidate = evaluateCandidate(userId, tpl);
            if (candidate != null) {
                randomPool.add(candidate);
            }
        }
        if (randomPool.size() < 2) {
            throw new ApiException(ErrorCode.QUEST_CONFIGURATION_INVALID);
        }

        Collections.shuffle(randomPool, random);
        List<EligibleCandidate> selected = List.of(slot1, slot2, randomPool.get(0), randomPool.get(1));

        UUID questSetId = repository.insertQuestSet(userId, questDate, issuedAt, expiresAt);
        List<DailyQuestItemResponse> items = new ArrayList<>(4);
        for (int i = 0; i < selected.size(); i++) {
            int slot = i + 1;
            EligibleCandidate candidate = selected.get(i);
            QuestTemplateRow tpl = candidate.template();
            UUID questId = repository.insertDailyQuest(questSetId, userId, questDate, slot, tpl);
            List<UUID> eligibleIds = "SAVED".equals(tpl.sourceScope()) ? candidate.savedMediaIds() : List.of();
            if (!eligibleIds.isEmpty()) {
                repository.insertEligibleMedia(questId, eligibleIds);
            }
            items.add(new DailyQuestItemResponse(
                    questId,
                    tpl.code(),
                    tpl.title(),
                    slot,
                    tpl.sourceScope(),
                    tpl.mediaType(),
                    tpl.targetCount(),
                    0,
                    "ACTIVE",
                    tpl.xpReward(),
                    eligibleIds));
        }

        return new DailyQuestSetResponse(questSetId, questDate, issuedAt, expiresAt, items);
    }

    @Transactional(readOnly = true)
    public DailyQuestSetResponse getToday(UUID userId) {
        LocalDate questDate = clock.instant().atZone(QUEST_ZONE).toLocalDate();
        QuestSetRow set = repository.findQuestSet(userId, questDate)
                .orElseThrow(() -> new ApiException(ErrorCode.QUEST_SET_NOT_ISSUED));
        return buildResponse(set);
    }

    @Transactional(readOnly = true)
    public PageResponse<ContentSummaryResponse> getQuestMedia(UUID userId, UUID questId, int page, int size) {
        DailyQuestRow quest = repository.findOwnedQuest(userId, questId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        return repository.findQuestMediaPage(userId, quest, page, size);
    }

    private DailyQuestSetResponse buildResponse(QuestSetRow set) {
        List<DailyQuestRow> rows = repository.findQuestsBySet(set.questSetId());
        List<UUID> savedQuestIds = rows.stream()
                .filter(q -> "SAVED".equals(q.sourceScope()))
                .map(DailyQuestRow::id)
                .toList();
        Map<UUID, List<UUID>> eligibleByQuest = repository.findEligibleMediaIdsByQuests(savedQuestIds);
        List<DailyQuestItemResponse> items = rows.stream()
                .map(q -> new DailyQuestItemResponse(
                        q.id(),
                        q.code(),
                        q.title(),
                        q.slot(),
                        q.sourceScope(),
                        q.mediaType(),
                        q.targetCount(),
                        q.progressCount(),
                        q.status(),
                        q.xpReward(),
                        "SAVED".equals(q.sourceScope())
                                ? eligibleByQuest.getOrDefault(q.id(), List.of())
                                : List.of()))
                .toList();
        return new DailyQuestSetResponse(
                set.questSetId(),
                set.questDate(),
                set.issuedAt(),
                set.expiresAt(),
                items);
    }

    private EligibleCandidate evaluateCandidate(UUID userId, QuestTemplateRow template) {
        if ("SAVED".equals(template.sourceScope())) {
            List<UUID> savedIds = repository.findAvailableSavedMediaIds(
                    userId, template.mediaType(), template.genreId());
            if (savedIds.size() < template.targetCount()) {
                return null;
            }
            return new EligibleCandidate(template, savedIds);
        }
        int availableCount = repository.countAvailableMedia(template.mediaType(), template.genreId());
        if (availableCount < template.targetCount()) {
            return null;
        }
        return new EligibleCandidate(template, List.of());
    }

    private QuestTemplateRow findByCode(List<QuestTemplateRow> templates, String code) {
        for (QuestTemplateRow tpl : templates) {
            if (code.equals(tpl.code())) {
                return tpl;
            }
        }
        return null;
    }

    private record EligibleCandidate(QuestTemplateRow template, List<UUID> savedMediaIds) {}
}
