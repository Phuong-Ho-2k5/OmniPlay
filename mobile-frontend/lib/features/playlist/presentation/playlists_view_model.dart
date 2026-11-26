import 'package:flutter/foundation.dart';

import '../../catalog/presentation/catalog_message.dart';
import '../data/playlist_repository.dart';
import '../models/playlist.dart';
import 'playlists_state.dart';

class PlaylistsViewModel extends ChangeNotifier {
  PlaylistsViewModel(this._repository);

  final PlaylistRepository _repository;
  static const int _pageSize = 20;

  List<PlaylistSummary> _items = [];
  int _sequence = 0;
  int _page = -1;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _disposed = false;
  String? _message;
  String? _moreMessage;
  String? _actionError;

  PlaylistsState get state => PlaylistsState(
    items: _items,
    loading: _loading,
    loadingMore: _loadingMore,
    page: _page,
    size: _pageSize,
    totalElements: _total,
    message: _message,
    moreMessage: _moreMessage,
    actionError: _actionError,
  );

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

  /// Creates a playlist using caller-supplied [requestId] so retries stay idempotent.
  Future<PlaylistSummary> createPlaylist({
    required String name,
    required String requestId,
  }) async {
    final created = await _repository.create(name: name, requestId: requestId);
    if (!_disposed) {
      final exists = _items.any((e) => e.id == created.id);
      if (exists) {
        _items = [
          for (final item in _items) item.id == created.id ? created : item,
        ];
      } else {
        _items = [created, ..._items];
        _total++;
      }
      _actionError = null;
      _emit();
    }
    return created;
  }

  Future<PlaylistRenamed> renamePlaylist({
    required String id,
    required String name,
  }) async {
    final renamed = await _repository.rename(id: id, name: name);
    if (!_disposed) {
      _items = [
        for (final item in _items)
          item.id == renamed.id
              ? item.copyWith(name: renamed.name, updatedAt: renamed.updatedAt)
              : item,
      ];
      _actionError = null;
      _emit();
    }
    return renamed;
  }

  Future<bool> deletePlaylist(String id) async {
    if (_disposed) return false;
    _actionError = null;
    _emit();
    try {
      await _repository.delete(id);
      if (_disposed) return true;
      final before = _items.length;
      _items = _items.where((e) => e.id != id).toList();
      if (_items.length < before && _total > 0) _total--;
      _emit();
      return true;
    } catch (error) {
      if (!_disposed) {
        _actionError = catalogErrorMessage(error);
        _emit();
      }
      return false;
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
