import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/catalog_repository.dart';
import '../models/content_type.dart';
import 'catalog_message.dart';
import 'content_detail_state.dart';

class ContentDetailViewModel extends ChangeNotifier {
  ContentDetailViewModel(this._repository);
  final CatalogRepository _repository;
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

  @override
  void dispose() {
    _disposed = true;
    _sequence++;
    super.dispose();
  }
}
