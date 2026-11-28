import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../catalog/data/catalog_repository.dart';
import '../../catalog/models/content_type.dart';
import '../../saved/data/saved_repository.dart';
import '../data/mystery_box_repository.dart';
import 'mystery_box_result_screen.dart';
import 'mystery_box_view_model.dart';

class MysteryBoxFilterScreen extends StatefulWidget {
  const MysteryBoxFilterScreen({
    super.key,
    required this.mysteryRepository,
    required this.catalogRepository,
    required this.savedRepository,
    required this.onOpenItem,
    this.onSavedChanged,
  });

  final MysteryBoxRepository mysteryRepository;
  final CatalogRepository catalogRepository;
  final SavedRepository savedRepository;
  final void Function(String id, ContentType type) onOpenItem;
  final VoidCallback? onSavedChanged;

  @override
  State<MysteryBoxFilterScreen> createState() => _MysteryBoxFilterScreenState();
}

class _MysteryBoxFilterScreenState extends State<MysteryBoxFilterScreen> {
  static const List<int?> _durationPresets = [null, 180, 300, 600, 1800];

  late final MysteryBoxViewModel _viewModel;
  final TextEditingController _customDurationController =
      TextEditingController();
  String? _durationError;

  @override
  void initState() {
    super.initState();
    _viewModel = MysteryBoxViewModel(
      mysteryRepository: widget.mysteryRepository,
      catalogRepository: widget.catalogRepository,
      savedRepository: widget.savedRepository,
      onSavedChanged: widget.onSavedChanged,
    );
    unawaited(_viewModel.loadGenres());
  }

  @override
  void dispose() {
    _customDurationController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  String _durationLabel(int? seconds) {
    if (seconds == null) return 'Không giới hạn';
    if (seconds < 60) return '≤ $seconds giây';
    return '≤ ${seconds ~/ 60} phút';
  }

  void _applyCustomDuration(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() => _durationError = null);
      _viewModel.setMaxDurationSeconds(null);
      return;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      setState(() => _durationError = 'Thời lượng tối đa phải lớn hơn 0 giây.');
      return;
    }
    setState(() => _durationError = null);
    _viewModel.setMaxDurationSeconds(parsed);
  }

  Future<void> _openBox() async {
    final rawCustom = _customDurationController.text.trim();
    if (rawCustom.isNotEmpty) {
      final parsed = int.tryParse(rawCustom);
      if (parsed == null || parsed <= 0) {
        setState(
          () => _durationError = 'Thời lượng tối đa phải lớn hơn 0 giây.',
        );
        return;
      }
      _viewModel.setMaxDurationSeconds(parsed);
    }
    setState(() => _durationError = null);

    final ok = await _viewModel.draw(excludeCurrent: false);
    if (!mounted || !ok) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MysteryBoxResultScreen(
          viewModel: _viewModel,
          catalogRepository: widget.catalogRepository,
          onOpenItem: widget.onOpenItem,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mystery Box'),
        actions: [
          TextButton(
            onPressed: () {
              _customDurationController.clear();
              setState(() => _durationError = null);
              _viewModel.resetFilters();
            },
            child: const Text('Đặt lại'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final state = _viewModel.state;
            final filter = state.filter;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Bớt lựa chọn.\nThêm bất ngờ.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chọn điều kiện mong muốn hoặc để trống để mở ngẫu nhiên một Video, bài nhạc hoặc Podcast.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text('Loại media', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả media'),
                      selected: filter.mediaType == null,
                      onSelected: state.drawing
                          ? null
                          : (_) => _viewModel.setMediaType(null),
                    ),
                    for (final type in const [
                      ContentType.video,
                      ContentType.music,
                      ContentType.podcast,
                    ])
                      ChoiceChip(
                        label: Text(type.label),
                        selected: filter.mediaType == type,
                        onSelected: state.drawing
                            ? null
                            : (_) => _viewModel.setMediaType(type),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Thể loại', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (state.loadingGenres)
                  const LinearProgressIndicator()
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Tất cả thể loại'),
                        selected: filter.genreId == null,
                        onSelected: state.drawing
                            ? null
                            : (_) => _viewModel.setGenreId(null),
                      ),
                      for (final genre in state.genres)
                        ChoiceChip(
                          label: Text(genre.name),
                          selected: filter.genreId == genre.id,
                          onSelected: state.drawing
                              ? null
                              : (_) => _viewModel.setGenreId(genre.id),
                        ),
                    ],
                  ),
                const SizedBox(height: 20),
                Text('Thời lượng tối đa', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in _durationPresets)
                      ChoiceChip(
                        label: Text(_durationLabel(preset)),
                        selected:
                            filter.maxDurationSeconds == preset &&
                            _customDurationController.text.trim().isEmpty,
                        onSelected: state.drawing
                            ? null
                            : (_) {
                                _customDurationController.clear();
                                setState(() => _durationError = null);
                                _viewModel.setMaxDurationSeconds(preset);
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customDurationController,
                  enabled: !state.drawing,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Hoặc nhập số giây tối đa (tùy chọn)',
                    hintText: 'Ví dụ: 240',
                    errorText: _durationError,
                  ),
                  onChanged: _applyCustomDuration,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: state.drawing
                        ? null
                        : () => unawaited(_openBox()),
                    icon: state.drawing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      state.drawing ? 'Đang mở hộp...' : 'Mở hộp bất ngờ',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Các bộ lọc kết hợp theo điều kiện AND và chỉ áp dụng cho Video, Nhạc và Podcast.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
