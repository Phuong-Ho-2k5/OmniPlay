import '../models/content_detail.dart';

class ContentDetailState {
  const ContentDetailState({
    this.loading = false,
    this.saving = false,
    this.detail,
    this.message,
    this.saveError,
    this.unavailable = false,
  });
  final bool loading, saving, unavailable;
  final ContentDetail? detail;
  final String? message;
  final String? saveError;
}
