import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../data/catalog_repository.dart';
import '../models/content_type.dart';

class CatalogThumbnail extends StatefulWidget {
  const CatalogThumbnail({
    super.key,
    required this.repository,
    required this.path,
    required this.type,
    this.height = 160,
  });
  final CatalogRepository repository;
  final String? path;
  final ContentType type;
  final double height;
  @override
  State<CatalogThumbnail> createState() => _CatalogThumbnailState();
}

class _CatalogThumbnailState extends State<CatalogThumbnail> {
  Future<Uint8List>? _image;
  MemoryImage? _provider;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CatalogThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.repository != widget.repository) {
      _provider?.evict();
      _provider = null;
      _load();
    }
  }

  void _load() {
    _image = widget.path == null
        ? null
        : widget.repository.thumbnail(widget.path!);
  }

  @override
  void dispose() {
    _provider?.evict();
    super.dispose();
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        switch (widget.type) {
          ContentType.video => Icons.ondemand_video,
          ContentType.music => Icons.music_note,
          ContentType.podcast => Icons.podcasts,
          ContentType.post => Icons.article_outlined,
        },
        size: 42,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || data == null) {
          return _placeholder(context);
        }
        _provider ??= MemoryImage(data);
        return Image(
          image: _provider!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _placeholder(context),
        );
      },
    ),
  );
}
