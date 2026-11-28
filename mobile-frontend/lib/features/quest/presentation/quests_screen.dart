import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/daily_quest.dart';
import 'quests_view_model.dart';

class QuestsScreen extends StatelessWidget {
  const QuestsScreen({
    super.key,
    required this.viewModel,
    required this.onOpenQuestMedia,
    required this.onLogout,
  });

  final QuestsViewModel viewModel;
  final void Function(DailyQuest quest) onOpenQuestMedia;
  final VoidCallback onLogout;

  Future<void> _handleClaim(BuildContext context, DailyQuest quest) async {
    final result = await viewModel.claimQuest(quest);
    if (!context.mounted || result == null) return;
    final parts = <String>[
      if (result.xpAwarded > 0)
        'Nhận +${result.xpAwarded} XP (Tổng ${result.totalXp} XP • Level ${result.level})'
      else
        'Quest đã được nhận thưởng trước đó (Tổng ${result.totalXp} XP • Level ${result.level})',
      if (result.newBadges.isNotEmpty)
        'Mở khóa huy hiệu: ${result.newBadges.map((b) => b.name).join(', ')}',
    ];
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(parts.join(' • '))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest hôm nay'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(viewModel.ensureToday()),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: onLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final state = viewModel.state;
            final questSet = state.questSet;
            if (state.loading && questSet == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (questSet == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.message != null
                            ? Icons.cloud_off_outlined
                            : Icons.emoji_events_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message ?? 'Chưa tải được bộ Quest hôm nay.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => unawaited(viewModel.ensureToday()),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (state.loading) const LinearProgressIndicator(),
                if (state.notice != null) ...[
                  MaterialBanner(
                    content: Text(state.notice!),
                    actions: [
                      TextButton(
                        onPressed: viewModel.clearNotice,
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (state.message != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(state.message!),
                    trailing: TextButton(
                      onPressed: () => unawaited(viewModel.ensureToday()),
                      child: const Text('Thử lại'),
                    ),
                  ),
                ],
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ngày ${questSet.questDate}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hoàn thành ${questSet.completedCount}/${questSet.quests.length} nhiệm vụ',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              if (state.latestTotalXp != null &&
                                  state.latestLevel != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Level ${state.latestLevel} • ${state.latestTotalXp} XP',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Hết hạn lúc 00:00 ngày kế tiếp (giờ Việt Nam).',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.emoji_events,
                          size: 36,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final quest in questSet.quests) ...[
                  _QuestCard(
                    quest: quest,
                    claiming: state.isClaiming(quest.id),
                    claimError: state.claimErrorFor(quest.id),
                    onOpenMedia: () => onOpenQuestMedia(quest),
                    onClaim: () => unawaited(_handleClaim(context, quest)),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.claiming,
    required this.claimError,
    required this.onOpenMedia,
    required this.onClaim,
  });

  final DailyQuest quest;
  final bool claiming;
  final String? claimError;
  final VoidCallback onOpenMedia;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scopeTag = quest.sourceScope == QuestSourceScope.saved
        ? 'Đã lưu (snapshot)'
        : 'Kho nội dung';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text('${quest.code} • Slot ${quest.slot}'),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(scopeTag),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                Text(
                  '+${quest.xpReward} XP',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(quest.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: quest.progressRatio),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${quest.progressCount}/${quest.targetCount} • ${quest.status.label}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: onOpenMedia,
                  icon: const Icon(Icons.playlist_play, size: 18),
                  label: const Text('Nội dung phù hợp'),
                ),
              ],
            ),
            if (claimError != null) ...[
              const SizedBox(height: 4),
              Text(
                claimError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (quest.status == QuestStatus.claimable) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: claiming ? null : onClaim,
                  child: claiming
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Đang nhận thưởng...'),
                          ],
                        )
                      : Text(
                          claimError != null
                              ? 'Thử nhận lại (+${quest.xpReward} XP)'
                              : 'Nhận +${quest.xpReward} XP',
                        ),
                ),
              ),
            ] else if (quest.status == QuestStatus.claimed) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Đã nhận thưởng',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
