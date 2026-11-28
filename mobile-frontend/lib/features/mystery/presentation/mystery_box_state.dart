import '../../catalog/models/content_summary.dart';
import '../../catalog/models/genre.dart';
import '../models/mystery_box.dart';

class MysteryBoxState {
  MysteryBoxState({
    required this.filter,
    required List<Genre> genres,
    required this.loadingGenres,
    required this.drawing,
    required this.saving,
    this.resultType,
    this.media,
    this.errorMessage,
    this.saveError,
  }) : genres = List.unmodifiable(genres);

  final MysteryBoxFilter filter;
  final List<Genre> genres;
  final bool loadingGenres;
  final bool drawing;
  final bool saving;
  final MysteryBoxResultType? resultType;
  final ContentSummary? media;
  final String? errorMessage;
  final String? saveError;
}
