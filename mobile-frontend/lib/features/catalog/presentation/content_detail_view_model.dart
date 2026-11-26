import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../saved/data/saved_repository.dart';
import '../data/catalog_repository.dart';
import '../models/content_detail.dart';
import '../models/content_summary.dart';
import '../models/content_type.dart';
import 'catalog_message.dart';
import 'content_detail_state.dart';

class ContentDetailViewModel extends ChangeNotifier {
  ContentDetailViewModel(this._repository, {this.savedRepository});

  final CatalogRepository _repository;
  final SavedRepository? savedRepository;
  ContentDetailState _state = const ContentDetailState();
  ContentDetailState get state => _state;
  int _sequence = 0;
  bool _disposed = false;

  Future<void> load({required String id, required ContentType type}) async {
    if (_disposed) return;
    final sequence = ++_sequence;
    _state = ContentDetailState(loading: true, detail: _state.detail);
    notifyListeners();
    try {
      final detail = await _repository.detail(id: id, type: type);
      if (_disposed || sequence != _sequence) return;
      _state = ContentDetailState(detail: detail);
    } catch (error) {
      if (_disposed || sequence != _sequence) return;
      final unavailable =
          error is ApiException && error.code == 'CONTENT_UNAVAILABLE';
      _state = ContentDetailState(
        message: catalogErrorMessage(error),
        unavailable: unavailable,
        detail: unavailable ? null : _state.detail,
      );
    }
    if (!_disposed && sequence == _sequence) notifyListeners();
  }

  Future<bool?> toggleSaved() async {
    final savedRepo = savedRepository;
    final current = _state.detail;
    if (_disposed || savedRepo == null || current == null || _state.saving) {
      return null;
    }
    final summary = current.summary;
    final targetSaved = !summary.saved;
    _state = ContentDetailState(detail: current, saving: true);
    notifyListeners();

    try {
      final result = await savedRepo.setSaved(
        id: summary.id,
        type: summary.type,
        saved: targetSaved,
      );
      if (_disposed) return result.saved;
      final updatedSummary = ContentSummary(
        id: summary.id,
        type: summary.type,
        title: summary.title,
        description: summary.description,
        thumbnailUrl: summary.thumbnailUrl,
        durationSeconds: summary.durationSeconds,
        genreIds: summary.genreIds,
        saved: result.saved,
      );
      _state = ContentDetailState(
        detail: ContentDetail(
          summary: updatedSummary,
          content: current.content,
        ),
      );
      notifyListeners();
      return result.saved;
    } catch (error) {
      if (_disposed) return null;
      _state = ContentDetailState(
        detail: current,
        saveError: catalogErrorMessage(error),
      );
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sequence++;
    super.dispose();
  }
}
