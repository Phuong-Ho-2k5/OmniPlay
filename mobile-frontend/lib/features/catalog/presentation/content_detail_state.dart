import '../models/content_detail.dart';

class ContentDetailState {
  const ContentDetailState({
    this.loading = false,
    this.detail,
    this.message,
    this.unavailable = false,
  });
  final bool loading, unavailable;
  final ContentDetail? detail;
  final String? message;
}
