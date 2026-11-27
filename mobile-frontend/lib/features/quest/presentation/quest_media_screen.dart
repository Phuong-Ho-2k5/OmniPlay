import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../catalog/data/catalog_repository.dart';
import '../../catalog/models/content_summary.dart';
import '../../catalog/models/content_type.dart';
import '../../catalog/presentation/catalog_message.dart';
import '../../catalog/presentation/content_card.dart';
import '../data/quest_repository.dart';
import '../models/daily_quest.dart';

class QuestMediaScreen extends StatefulWidget {
  const QuestMediaScreen({
    super.key,
    required this.quest,
    required this.questRepository,
    required this.catalogRepository,
    required this.onOpenItem,
  });

  final DailyQuest quest;
  final QuestRepository questRepository;
  final CatalogRepository catalogRepository;
  final void Function(String id, ContentType type) onOpenItem;

  @override
  State<QuestMediaScreen> createState() => _QuestMediaScreenState();
}

class _QuestMediaScreenState extends State<QuestMediaScreen> {
  static const int _pageSize = 20;

  List<ContentSummary> _items = [];
  int _page = -1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _message;
  String? _moreMessage;

  bool get _canLoadMore =>
      !_loading && _page >= 0 && (_page + 1) * _pageSize < _total;

  @override
  void initState() {
    super.initState();
    unawaited(_load(0, reset: true));
  }

  Future<void> _load(int page, {required bool reset}) async {
    setState(() {
      if (page == 0) {
        if (reset) {
          _items = [];
          _page = -1;
          _total = 0;
        }
        _loading = true;
        _message = null;
        _moreMessage = null;
      } else {
        _loadingMore = true;
        _moreMessage = null;
      }
    });

    try {
      final response = await widget.questRepository.getQuestMedia(
        widget.quest.id,
        page: page,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = page == 0 ? response.items : [..._items, ...response.items];
        _page = response.page;
        _total = response.totalElements;
        _loading = false;
        _loadingMore = false;
        _message = null;
        _moreMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (page == 0) {
          _message = catalogErrorMessage(error);
        } else {
          _moreMessage = catalogErrorMessage(error);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quest.title),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_load(0, reset: false)),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_loading && _items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _message != null
                            ? Icons.cloud_off_outlined
                            : Icons.inbox_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _message ?? 'Không có media khả dụng nào phù hợp với nhiệm vụ này.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (_message != null)
                        FilledButton(
                          onPressed: () => unawaited(_load(0, reset: true)),
                          child: const Text('Thử lại'),
                        ),
                    ],
                  ),
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                if (_loading)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                if (widget.quest.sourceScope == QuestSourceScope.saved)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Card(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Danh sách media Đã lưu được chụp cố định tại thời điểm cấp bộ Quest hôm nay.',
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverList.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ContentCard(
                          item: item,
                          repository: widget.catalogRepository,
                          onTap: () => widget.onOpenItem(item.id, item.type),
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_moreMessage != null)
                          Text(_moreMessage!, textAlign: TextAlign.center),
                        if (_loadingMore)
                          const CircularProgressIndicator()
                        else if (_canLoadMore)
                          OutlinedButton(
                            onPressed: () =>
                                unawaited(_load(_page + 1, reset: false)),
                            child: Text(
                              _moreMessage == null ? 'Tải thêm' : 'Thử lại',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
