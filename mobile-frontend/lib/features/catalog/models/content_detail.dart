import 'catalog_json.dart';
import 'content_summary.dart';
import 'content_type.dart';

class ContentDetail {
  const ContentDetail({required this.summary, this.content});
  final ContentSummary summary;
  final String? content;

  factory ContentDetail.fromJson(Map<String, dynamic> json) {
    final summary = ContentSummary.fromJson(json);
    final content = catalogNullableString(json['content']);
    if (summary.type == ContentType.post && content == null) {
      invalidCatalogResponse();
    }
    if (summary.type != ContentType.post && content != null) {
      invalidCatalogResponse();
    }
    return ContentDetail(summary: summary, content: content);
  }
}
