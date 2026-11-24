import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../playback/presentation/media_player_view_model.dart';
import '../data/catalog_repository.dart';
import '../models/content_type.dart';
import 'catalog_view_model.dart';
import 'content_card.dart';
import 'content_detail_screen.dart';

typedef PlayerViewModelFactory = MediaPlayerViewModel Function({
  required String mediaId,
  required ContentType type,
});

/// A session owns its entire navigation stack, including detail routes.
class CatalogSession extends StatefulWidget {
  const CatalogSession({
    super.key,
    required this.repository,
    required this.createViewModel,
    required this.createPlayerViewModel,
    required this.onLogout,
  });
  final CatalogRepository repository;
  final CatalogViewModel Function() createViewModel;
  final PlayerViewModelFactory createPlayerViewModel;
  final VoidCallback onLogout;
  @override
  State<CatalogSession> createState() => _CatalogSessionState();
}

class _CatalogSessionState extends State<CatalogSession> {
  final _navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => NavigatorPopHandler<void>(
    onPopWithResult: (_) => _navigator.currentState!.pop(),
    child: Navigator(
      key: _navigator,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => CatalogScreen(
          repository: widget.repository,
          createViewModel: widget.createViewModel,
          createPlayerViewModel: widget.createPlayerViewModel,
          onLogout: widget.onLogout,
        ),
      ),
    ),
  );
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.repository,
    required this.createViewModel,
    required this.createPlayerViewModel,
    required this.onLogout,
  });
  final CatalogRepository repository;
  final CatalogViewModel Function() createViewModel;
  final PlayerViewModelFactory createPlayerViewModel;
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
                                id: item.id,
                                type: item.type,
                                genres: state.genres,
                                createPlayerViewModel:
                                    widget.createPlayerViewModel,
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
