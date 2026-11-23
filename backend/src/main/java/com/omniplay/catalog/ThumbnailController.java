package com.omniplay.catalog;

import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ThumbnailController {
    private final ThumbnailService thumbnails;
    private final CatalogInputValidator input;
    public ThumbnailController(ThumbnailService thumbnails, CatalogInputValidator input) {
        this.thumbnails = thumbnails;
        this.input = input;
    }

    @GetMapping("/media/{id}/thumbnail")
    public ResponseEntity<byte[]> thumbnail(@PathVariable String id) {
        var image = thumbnails.load(input.uuid(id, "id"));
        return ResponseEntity.ok().cacheControl(CacheControl.noStore().cachePrivate())
                .contentType(image.contentType()).contentLength(image.bytes().length).body(image.bytes());
    }
}
