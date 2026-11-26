import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../playback/presentation/media_player_view_model.dart';
import '../../playback/presentation/mini_player_bar.dart';
import '../../playback/presentation/player_coordinator.dart';
import '../../saved/data/saved_repository.dart';
import '../../saved/presentation/saved_screen.dart';
import '../../saved/presentation/saved_view_model.dart';
import '../data/catalog_repository.dart';
import '../models/content_type.dart';
import 'catalog_view_model.dart';
import 'content_card.dart';
import 'content_detail_screen.dart';

typedef PlayerViewModelFactory = MediaPlayerViewModel Function({
  required String mediaId,
  required ContentType type,
  Future<void> Function()? onBeforeVideoPlay,
});

/// A session owns its entire navigation stack, including detail routes, tabs, and mini player.
class CatalogSession extends StatefulWidget {
  const CatalogSession({
    super.key,
    required this.repository,
    required this.savedRepository,
    required this.createViewModel,
    required this.createSavedViewModel,
    required this.createPlayerViewModel,
    required this.createPlayerCoordinator,
    required this.onLogout,
  });
  final CatalogRepository repository;
  final SavedRepository savedRepository;
  final CatalogViewModel Function() createViewModel;
  final SavedViewModel Function() createSavedViewModel;
  final PlayerViewModelFactory createPlayerViewModel;
  final PlayerCoordinator Function() createPlayerCoordinator;
  final VoidCallback onLogout;
  @override
  State<CatalogSession> createState() => _CatalogSessionState();
}

class _CatalogSessionState extends State<CatalogSession> {
  final _navigator = GlobalKey<NavigatorState>();
  late final PlayerCoordinator _coordinator;
  late final SavedViewModel _savedViewModel;
  final ValueNotifier<int> _tabIndex = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _coordinator = widget.createPlayerCoordinator();
    _savedViewModel = widget.createSavedViewModel();
    unawaited(_coordinator.restoreSessions());
  }

  @override
  void dispose() {
    _tabIndex.dispose();
    _savedViewModel.dispose();
    _coordinator.dispose();
    super.dispose();
  }

  void _openDetail(String id, ContentType type) {
    _navigator.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ContentDetailScreen(
          repository: widget.repository,
          savedRepository: widget.savedRepository,
          onSavedChanged: () => unawaited(_savedViewModel.refresh()),
          id: id,
          type: type,
          genres: const [],
          createPlayerViewModel: widget.createPlayerViewModel,
          playerCoordinator: _coordinator,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => NavigatorPopHandler<void>(
    onPopWithResult: (_) => _navigator.currentState!.pop(),
    child: Column(
      children: [
        Expanded(
          child: Navigator(
            key: _navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => ValueListenableBuilder<int>(
                valueListenable: _tabIndex,
                builder: (context, index, _) => IndexedStack(
                  index: index,
                  children: [
                    CatalogScreen(
                      repository: widget.repository,
                      savedRepository: widget.savedRepository,
                      onSavedChanged: () =>
                          unawaited(_savedViewModel.refresh()),
                      createViewModel: widget.createViewModel,
                      createPlayerViewModel: widget.createPlayerViewModel,
                      playerCoordinator: _coordinator,
                      onLogout: widget.onLogout,
                    ),
                    SavedScreen(
                      viewModel: _savedViewModel,
                      catalogRepository: widget.repository,
                      onOpenItem: _openDetail,
                      onLogout: widget.onLogout,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        MiniPlayerBar(
          coordinator: _coordinator,
          onOpenDetail: (mediaId, sessionType) =>
              _openDetail(mediaId, sessionType.contentType),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _tabIndex,
          builder: (context, index, _) => NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (next) {
              if (_navigator.currentState?.canPop() ?? false) {
                _navigator.currentState!.popUntil((route) => route.isFirst);
              }
              _tabIndex.value = next;
              if (next == 1) {
                unawaited(_savedViewModel.refresh());
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Khám phá',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.bookmark),
                label: 'Đã lưu',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.repository,
    required this.savedRepository,
    required this.onSavedChanged,
    required this.createViewModel,
    required this.createPlayerViewModel,
    required this.playerCoordinator,
    required this.onLogout,
  });
  final CatalogRepository repository;
  final SavedRepository savedRepository;
  final VoidCallback onSavedChanged;
  final CatalogViewModel Function() createViewModel;
  final PlayerViewModelFactory createPlayerViewModel;
  final PlayerCoordinator playerCoordinator;
  final VoidCallback onLogout;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final CatalogViewModel _viewModel;
  final TextEditingController _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _viewModel = widget.createViewModel();
    unawaited(_viewModel.loadInitial());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    unawaited(_viewModel.clearFilters());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Khám phá'),
      actions: [
        IconButton(
          key: const Key('auth.logout'),
          tooltip: 'Đăng xuất',
          icon: const Icon(Icons.logout),
          onPressed: widget.onLogout,
        ),
      ],
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final state = _viewModel.state;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: _viewModel.setKeyword,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: 'Tìm theo tiêu đề',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Xóa từ khóa',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _viewModel.setKeyword('');
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Tất cả'),
                              selected: state.query.type == null,
                              onSelected: (_) => _viewModel.setType(null),
                            ),
                            for (final type in ContentType.values)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ChoiceChip(
                                  label: Text(type.label),
                                  selected: state.query.type == type,
                                  onSelected: (_) => _viewModel.setType(type),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(state.query.genreId),
                        initialValue: state.query.genreId ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Thể loại',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Tất cả thể loại'),
                          ),
                          for (final genre in state.genres)
                            DropdownMenuItem(
                              value: genre.id,
                              child: Text(genre.name),
                            ),
                        ],
                        onChanged: (value) =>
                            _viewModel.setGenre(value == '' ? null : value),
                      ),
                      if (state.loadingGenres)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(),
                        ),
                      if (state.genresMessage != null)
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Chưa tải được thể loại. Bạn vẫn có thể xem danh mục.',
                              ),
                            ),
                            TextButton(
                              onPressed: _viewModel.loadGenres,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      if (state.query.type == ContentType.post &&
                          state.query.genreId != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Post không có thể loại. Bỏ bộ lọc thể loại để xem bài viết.',
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _clear,
                          child: const Text('Xóa bộ lọc'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.loading && state.items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state.message == null
                              ? Icons.search_off
                              : Icons.cloud_off_outlined,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.message ?? 'Không có nội dung phù hợp. Hãy đổi từ khóa hoặc bộ lọc.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        if (state.message != null)
                          FilledButton(
                            onPressed: _viewModel.retry,
                            child: const Text('Thử lại'),
                          )
                        else
                          TextButton(
                            onPressed: _clear,
                            child: const Text('Xóa bộ lọc'),
                          ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (state.loading)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                if (state.message != null)
                  SliverToBoxAdapter(
                    child: ListTile(
                      title: Text(state.message!),
                      trailing: TextButton(
                        onPressed: _viewModel.retry,
                        child: const Text('Thử lại'),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.builder(
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ContentCard(
                          key: ValueKey('${item.type.apiValue}:${item.id}'),
                          item: item,
                          repository: widget.repository,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ContentDetailScreen(
                                repository: widget.repository,
                                savedRepository: widget.savedRepository,
                                onSavedChanged: () {
                                  widget.onSavedChanged();
                                  unawaited(_viewModel.retry());
                                },
                                id: item.id,
                                type: item.type,
                                genres: state.genres,
                                createPlayerViewModel:
                                    widget.createPlayerViewModel,
                                playerCoordinator: widget.playerCoordinator,
                              ),
                            ),
                          ),
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
                        if (state.moreMessage != null)
                          Text(state.moreMessage!, textAlign: TextAlign.center),
                        if (state.loadingMore)
                          const CircularProgressIndicator()
                        else if (state.canLoadMore)
                          OutlinedButton(
                            onPressed: _viewModel.loadMore,
                            child: Text(
                              state.moreMessage == null
                                  ? 'Tải thêm'
                                  : 'Thử lại',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}
