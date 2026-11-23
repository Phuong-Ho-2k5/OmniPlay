import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/catalog_repository.dart';
import '../models/catalog_query.dart';
import '../models/content_summary.dart';
import '../models/content_type.dart';
import '../models/genre.dart';
import 'catalog_message.dart';
import 'catalog_state.dart';

class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel(this._repository);
  final CatalogRepository _repository;
  CatalogQuery _query = const CatalogQuery();
  List<ContentSummary> _items = [];
  List<Genre> _genres = [];
  int _sequence = 0, _page = -1, _total = 0;
  bool _disposed = false,
      _loading = false,
      _loadingMore = false,
      _loadingGenres = false;
  String? _message, _moreMessage, _genresMessage;
  Timer? _debounce;

  CatalogState get state => CatalogState(
    query: _query,
    items: _items,
    genres: _genres,
    loading: _loading,
    loadingMore: _loadingMore,
    loadingGenres: _loadingGenres,
    page: _page,
    totalElements: _total,
    message: _message,
    moreMessage: _moreMessage,
    genresMessage: _genresMessage,
  );

  Future<void> loadInitial() async {
    await Future.wait([_reset(_query), loadGenres()]);
  }

  void setKeyword(String value) {
    if (_disposed || value == _query.keyword) return;
    _change(
      CatalogQuery(keyword: value, type: _query.type, genreId: _query.genreId),
      debounce: true,
    );
  }

  void setType(ContentType? value) {
    if (_disposed || value == _query.type) return;
    _change(
      CatalogQuery(
        keyword: _query.keyword,
        type: value,
        genreId: _query.genreId,
      ),
    );
  }

  void setGenre(String? value) {
    if (_disposed || value == _query.genreId) return;
    _change(
      CatalogQuery(keyword: _query.keyword, type: _query.type, genreId: value),
    );
  }

  Future<void> clearFilters() => _reset(const CatalogQuery());
  Future<void> retry() => _reset(_query, keepItems: true);

  void _change(CatalogQuery query, {bool debounce = false}) {
    unawaited(_reset(query, debounce: debounce));
  }

  Future<void> _reset(
    CatalogQuery query, {
    bool debounce = false,
    bool keepItems = false,
  }) async {
    if (_disposed) return;
    _debounce?.cancel();
    final sequence = ++_sequence;
    _query = query.atPage(0);
    if (!keepItems) {
      _items = [];
      _page = -1;
      _total = 0;
    }
    _message = null;
    _moreMessage = null;
    _loadingMore = false;
    _loading = true;
    if (query.keyword.trim().runes.length > 200) {
      _loading = false;
      _message = 'Từ khóa tối đa 200 ký tự.';
      _emit();
      return;
    }
    _emit();
    if (debounce) {
      _debounce = Timer(
        const Duration(milliseconds: 300),
        () => unawaited(_load(0, sequence)),
      );
    } else {
      await _load(0, sequence);
    }
  }

  Future<void> loadMore() async {
    if (_disposed || _loading || _loadingMore || !state.canLoadMore) return;
    await _load(_page + 1, _sequence);
  }

  Future<void> _load(int page, int sequence) async {
    if (_disposed || sequence != _sequence) return;
    if (page > 0) {
      _loadingMore = true;
      _moreMessage = null;
      _emit();
    }
    try {
      final response = await _repository.list(_query.atPage(page));
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

  Future<void> loadGenres() async {
    if (_disposed || _loadingGenres) return;
    _loadingGenres = true;
    _genresMessage = null;
    _emit();
    try {
      final genres = await _repository.genres();
      if (!_disposed) _genres = genres;
    } catch (error) {
      if (!_disposed) _genresMessage = catalogErrorMessage(error);
    } finally {
      if (!_disposed) {
        _loadingGenres = false;
        _emit();
      }
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sequence++;
    _debounce?.cancel();
    super.dispose();
  }
}
