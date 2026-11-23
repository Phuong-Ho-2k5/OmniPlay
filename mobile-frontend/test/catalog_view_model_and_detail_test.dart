import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omniplay_mobile/core/network/api_exception.dart';
import 'package:omniplay_mobile/features/catalog/data/catalog_repository.dart';
import 'package:omniplay_mobile/features/catalog/models/catalog_page.dart';
import 'package:omniplay_mobile/features/catalog/models/catalog_query.dart';
import 'package:omniplay_mobile/features/catalog/models/content_detail.dart';
import 'package:omniplay_mobile/features/catalog/models/content_summary.dart';
import 'package:omniplay_mobile/features/catalog/models/content_type.dart';
import 'package:omniplay_mobile/features/catalog/models/genre.dart';
import 'package:omniplay_mobile/features/catalog/presentation/catalog_view_model.dart';
import 'package:omniplay_mobile/features/catalog/presentation/content_detail_view_model.dart';

class FakeCatalogRepository implements CatalogRepository {
  Future<CatalogPage> Function(CatalogQuery query)? onList;
  Future<List<Genre>> Function()? onGenres;
  Future<ContentDetail> Function(String id, ContentType type)? onDetail;

  @override
  Future<CatalogPage> list(CatalogQuery query) => onList!(query);

  @override
  Future<List<Genre>> genres() => onGenres?.call() ?? Future.value(const []);

  @override
  Future<ContentDetail> detail({
    required String id,
    required ContentType type,
  }) => onDetail!(id, type);

  @override
  Future<Uint8List> thumbnail(String relativePath) async => Uint8List(0);
}

ContentSummary _item(int i, {ContentType type = ContentType.video}) =>
    ContentSummary(
      id: '20000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
      type: type,
      title: 'Item $i',
      description: 'Desc $i',
      thumbnailUrl: null,
      durationSeconds: type == ContentType.post ? null : 60,
      genreIds: const [],
      saved: false,
    );

void main() {
  test('CatalogViewModel ignores stale responses when query changes rapidly', () async {
    final repo = FakeCatalogRepository();
    final slowFirst = Completer<CatalogPage>();

    repo.onList = (query) {
      if (query.type == ContentType.video) {
        return slowFirst.future;
      }
      return Future.value(
        CatalogPage(
          items: [_item(2, type: ContentType.post)],
          page: 0,
          size: 20,
          totalElements: 1,
        ),
      );
    };

    final vm = CatalogViewModel(repo);
    vm.setType(ContentType.video);
    vm.setType(ContentType.post);
    await Future<void>.delayed(Duration.zero);

    expect(vm.state.items.map((e) => e.title), ['Item 2']);

    // Stale first response arrives late -> must be ignored
    slowFirst.complete(
      CatalogPage(
        items: [_item(1, type: ContentType.video)],
        page: 0,
        size: 20,
        totalElements: 1,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(vm.state.items.map((e) => e.title), ['Item 2']);
    vm.dispose();
  });

  test('CatalogViewModel debounces keyword and keeps page 0 items on loadMore failure', () async {
    final repo = FakeCatalogRepository();
    final queries = <CatalogQuery>[];
    var failPage1 = true;

    repo.onList = (query) async {
      queries.add(query);
      if (query.page == 0) {
        return CatalogPage(
          items: [for (var i = 1; i <= 20; i++) _item(i)],
          page: 0,
          size: 20,
          totalElements: 21,
        );
      }
      if (failPage1) {
        throw const ApiException(
          kind: ApiFailureKind.network,
          code: 'NETWORK_ERROR',
          message: 'offline',
        );
      }
      return CatalogPage(
        items: [_item(21)],
        page: 1,
        size: 20,
        totalElements: 21,
      );
    };

    final vm = CatalogViewModel(repo);
    vm.setKeyword('a');
    vm.setKeyword('ab');
    vm.setKeyword('abc');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(queries.length, 1);
    expect(queries.single.keyword, 'abc');
    expect(vm.state.items.length, 20);
    expect(vm.state.canLoadMore, isTrue);

    // Page 1 fails -> keeps page 0 items and sets moreMessage
    await vm.loadMore();
    expect(vm.state.items.length, 20);
    expect(vm.state.moreMessage, isNotNull);
    expect(vm.state.message, isNull);

    // Retry loadMore succeeds
    failPage1 = false;
    await vm.loadMore();
    expect(vm.state.items.length, 21);
    expect(vm.state.moreMessage, isNull);
    expect(vm.state.canLoadMore, isFalse);

    // Keyword > 200 code points fails locally without hitting repo
    final beforeCount = queries.length;
    vm.setKeyword('x' * 201);
    expect(vm.state.message, isNotNull);
    expect(queries.length, beforeCount);
    vm.dispose();
  });

  test('ContentDetailViewModel distinguishes CONTENT_UNAVAILABLE from generic errors', () async {
    final repo = FakeCatalogRepository();
    repo.onDetail = (id, type) async => throw const ApiException(
      kind: ApiFailureKind.http,
      statusCode: 404,
      code: 'CONTENT_UNAVAILABLE',
      message: 'Unavailable',
    );

    final vm = ContentDetailViewModel(repo);
    await vm.load(
      id: '20000000-0000-4000-8000-000000000001',
      type: ContentType.post,
    );
    expect(vm.state.unavailable, isTrue);
    expect(vm.state.detail, isNull);
    expect(vm.state.message, isNotNull);
    vm.dispose();
  });
}
