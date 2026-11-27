import 'package:flutter/foundation.dart';

import '../../catalog/presentation/catalog_message.dart';
import '../data/playlist_repository.dart';
import '../models/cleanup_suggestion.dart';
import 'cleanup_suggestions_state.dart';

class CleanupSuggestionsViewModel extends ChangeNotifier {
  CleanupSuggestionsViewModel(this._repository, {this.onChanged});

  final PlaylistRepository _repository;
  final VoidCallback? onChanged;

  List<CleanupSuggestionItem> _items = [];
  bool _loading = false;
  final Set<String> _busyItemIds = {};
  String? _message;
  String? _actionError;
  String? _feedbackMessage;
  bool _disposed = false;
  int _sequence = 0;

  CleanupSuggestionsState get state => CleanupSuggestionsState(
    items: _items,
    loading: _loading,
    busyItemIds: _busyItemIds,
    message: _message,
    actionError: _actionError,
    feedbackMessage: _feedbackMessage,
  );

  Future<void> load() async {
    if (_disposed) return;
    final seq = ++_sequence;
    _loading = true;
    _message = null;
    _emit();

    try {
      final fetched = await _repository.fetchCleanupSuggestions();
      if (_disposed || seq != _sequence) return;
      _items = fetched;
      _message = null;
    } catch (error) {
      if (_disposed || seq != _sequence) return;
      _message = catalogErrorMessage(error);
    } finally {
      if (!_disposed && seq == _sequence) {
        _loading = false;
        _emit();
      }
    }
  }

  Future<bool> applyAction(
    CleanupSuggestionItem item,
    CleanupAction action,
  ) async {
    if (_disposed || _busyItemIds.contains(item.playlistItemId)) return false;
    _busyItemIds.add(item.playlistItemId);
    _actionError = null;
    _feedbackMessage = null;
    _emit();

    try {
      final result = await _repository.applyCleanupAction(
        playlistItemId: item.playlistItemId,
        action: action,
      );
      if (_disposed) return true;
      if (!result.suggestionVisible || result.removed) {
        _items = _items
            .where((e) => e.playlistItemId != item.playlistItemId)
            .toList();
      }
      _feedbackMessage = switch (action) {
        CleanupAction.keep =>
          'Đã giữ "${item.title}" và đặt lại bộ đếm bỏ qua về 0.',
        CleanupAction.dismiss =>
          'Đã ẩn gợi ý cho "${item.title}" cho đến lượt skip hợp lệ kế tiếp.',
        CleanupAction.remove => 'Đã gỡ "${item.title}" khỏi playlist.',
      };
      onChanged?.call();
      return true;
    } catch (error) {
      if (!_disposed) {
        _actionError = catalogErrorMessage(error);
      }
      return false;
    } finally {
      if (!_disposed) {
        _busyItemIds.remove(item.playlistItemId);
        _emit();
      }
    }
  }

  void clearActionError() {
    if (_actionError == null) return;
    _actionError = null;
    _emit();
  }

  void clearFeedback() {
    if (_feedbackMessage == null) return;
    _feedbackMessage = null;
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
