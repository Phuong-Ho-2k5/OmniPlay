import 'package:flutter/foundation.dart';

import '../../catalog/data/catalog_repository.dart';
import '../../catalog/models/content_summary.dart';
import '../../catalog/models/content_type.dart';
import '../../catalog/models/genre.dart';
import '../../catalog/presentation/catalog_message.dart';
import '../../saved/data/saved_repository.dart';
import '../data/mystery_box_repository.dart';
import '../models/mystery_box.dart';
import 'mystery_box_state.dart';

class MysteryBoxViewModel extends ChangeNotifier {
  MysteryBoxViewModel({
    required this.mysteryRepository,
    required this.catalogRepository,
    required this.savedRepository,
    this.onSavedChanged,
  });

  final MysteryBoxRepository mysteryRepository;
  final CatalogRepository catalogRepository;
  final SavedRepository savedRepository;
  final VoidCallback? onSavedChanged;

  MysteryBoxFilter _filter = const MysteryBoxFilter();
  List<Genre> _genres = [];
  bool _loadingGenres = false;
  bool _drawing = false;
  bool _saving = false;
  MysteryBoxResultType? _resultType;
  ContentSummary? _media;
  String? _errorMessage;
  String? _saveError;
  bool _disposed = false;

  MysteryBoxState get state => MysteryBoxState(
    filter: _filter,
    genres: _genres,
    loadingGenres: _loadingGenres,
    drawing: _drawing,
    saving: _saving,
    resultType: _resultType,
    media: _media,
    errorMessage: _errorMessage,
    saveError: _saveError,
  );

  Future<void> loadGenres() async {
    if (_disposed || _loadingGenres || _genres.isNotEmpty) return;
    _loadingGenres = true;
    _emit();
    try {
      final fetched = await catalogRepository.genres();
      if (_disposed) return;
      _genres = fetched;
    } catch (_) {
      // Non-fatal: user can still draw without genre filter.
    } finally {
      if (!_disposed) {
        _loadingGenres = false;
        _emit();
      }
    }
  }

  void setMediaType(ContentType? type) {
    if (type == ContentType.post) return;
    _filter = _filter.copyWith(mediaType: type, clearMediaType: type == null);
    _emit();
  }

  void setGenreId(String? genreId) {
    _filter = _filter.copyWith(genreId: genreId, clearGenreId: genreId == null);
    _emit();
  }

  void setMaxDurationSeconds(int? seconds) {
    _filter = _filter.copyWith(
      maxDurationSeconds: seconds,
      clearMaxDuration: seconds == null,
    );
    _emit();
  }

  void resetFilters() {
    _filter = const MysteryBoxFilter();
    _emit();
  }

  Future<bool> draw({bool excludeCurrent = false}) async {
    if (_disposed || _drawing) return false;
    final excludeId = excludeCurrent ? _media?.id : null;
    _drawing = true;
    _errorMessage = null;
    _saveError = null;
    _emit();

    try {
      final response = await mysteryRepository.draw(
        _filter,
        excludeMediaId: excludeId,
      );
      if (_disposed) return true;
      _resultType = response.result;
      _media = response.media;
      _errorMessage = null;
      return true;
    } catch (error) {
      if (!_disposed) {
        _errorMessage = catalogErrorMessage(error);
      }
      return false;
    } finally {
      if (!_disposed) {
        _drawing = false;
        _emit();
      }
    }
  }

  Future<void> toggleSaved() async {
    final current = _media;
    if (_disposed || _saving || current == null) return;
    final targetSaved = !current.saved;
    _saving = true;
    _saveError = null;
    _emit();

    try {
      final confirmed = await savedRepository.setSaved(
        id: current.id,
        type: current.type,
        saved: targetSaved,
      );
      if (_disposed) return;
      _media = ContentSummary(
        id: current.id,
        type: current.type,
        title: current.title,
        description: current.description,
        thumbnailUrl: current.thumbnailUrl,
        durationSeconds: current.durationSeconds,
        genreIds: current.genreIds,
        saved: confirmed.saved,
      );
      onSavedChanged?.call();
    } catch (error) {
      if (!_disposed) {
        _saveError = catalogErrorMessage(error);
      }
    } finally {
      if (!_disposed) {
        _saving = false;
        _emit();
      }
    }
  }

  void clearSaveError() {
    if (_saveError == null) return;
    _saveError = null;
    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
