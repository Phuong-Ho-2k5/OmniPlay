import 'package:flutter/foundation.dart';

import '../../catalog/models/content_type.dart';
import '../../catalog/presentation/catalog_message.dart';
import '../data/saved_repository.dart';
import '../models/saved_content_summary.dart';
import 'saved_state.dart';

class SavedViewModel extends ChangeNotifier {
  SavedViewModel(this._repository);

  final SavedRepository _repository;
  static const int _pageSize = 20;

  List<SavedContentSummary> _items = [];
  final Set<String> _pendingKeys = {};
  int _sequence = 0;
  int _page = -1;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _disposed = false;
  String? _message;
  String? _moreMessage;
  String? _actionError;

  SavedState get state => SavedState(
    items: _items,
    loading: _loading,
    loadingMore: _loadingMore,
    page: _page,
    size: _pageSize,
    totalElements: _total,
    pendingKeys: _pendingKeys,
    message: _message,
    moreMessage: _moreMessage,
    actionError: _actionError,
  );

  static String itemKey(String id, ContentType type) => '${type.apiValue}:$id';

  Future<void> loadInitial() => _load(0, reset: true);
  Future<void> refresh() => _load(0, reset: false);

  Future<void> loadMore() async {
    if (_disposed || _loading || _loadingMore || !state.canLoadMore) return;
    await _load(_page + 1, reset: false);
  }

  Future<void> _load(int page, {required bool reset}) async {
    if (_disposed) return;
    final sequence = page == 0 ? ++_sequence : _sequence;
    if (page == 0) {
      if (reset) {
        _items = [];
        _page = -1;
        _total = 0;
      }
      _loading = true;
      _loadingMore = false;
      _message = null;
      _moreMessage = null;
    } else {
      _loadingMore = true;
      _moreMessage = null;
    }
    _emit();

    try {
      final response = await _repository.list(page: page, size: _pageSize);
      if (_disposed || sequence != _sequence) return;
      _items = page == 0 ? response.items : [..._items, ...response.items];
      _page = response.page;
      _total = response.totalElements;
      _message = null;
      _moreMessage = null;
    } catch (error) {
      if (_disposed || sequence != _sequence) return;
      if (page == 0) {
        _message = catalogErrorMessage(error);
      } else {
        _moreMessage = catalogErrorMessage(error);
      }
    } finally {
      if (!_disposed && sequence == _sequence) {
        _loading = false;
        _loadingMore = false;
        _emit();
      }
    }
  }

  Future<bool> unsaveItem(SavedContentSummary item) async {
    final key = itemKey(item.summary.id, item.summary.type);
    if (_disposed || _pendingKeys.contains(key)) return false;
    _pendingKeys.add(key);
    _actionError = null;
    _emit();

    try {
      await _repository.setSaved(
        id: item.summary.id,
        type: item.summary.type,
        saved: false,
      );
      if (_disposed) return true;
      _items = _items
          .where((e) => itemKey(e.summary.id, e.summary.type) != key)
          .toList();
      if (_total > 0) _total--;
      return true;
    } catch (error) {
      if (!_disposed) {
        _actionError = catalogErrorMessage(error);
      }
      return false;
    } finally {
      _pendingKeys.remove(key);
      _emit();
    }
  }

  void clearActionError() {
    if (_actionError == null) return;
    _actionError = null;
    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sequence++;
    super.dispose();
  }
}
