package com.omniplay.catalog;

import java.util.UUID;

public record CatalogQuery(String q, ContentType type, UUID genreId, int page, int size) {}
