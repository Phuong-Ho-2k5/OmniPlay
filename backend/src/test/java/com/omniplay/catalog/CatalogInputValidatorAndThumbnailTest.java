package com.omniplay.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.config.MediaProperties;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.http.MediaType;

class CatalogInputValidatorAndThumbnailTest {
    private final CatalogInputValidator validator = new CatalogInputValidator();

    @Test
    void validatorParsesValidQueryAndRejectsBoundsAndMalformedInputs() {
        UUID genreId = UUID.randomUUID();
        CatalogQuery parsed = validator.parse("  Nhạc %_\\  ", "MUSIC", genreId.toString(), "2", "50", true);
        assertThat(parsed.q()).isEqualTo("Nhạc %_\\");
        assertThat(parsed.type()).isEqualTo(ContentType.MUSIC);
        assertThat(parsed.genreId()).isEqualTo(genreId);
        assertThat(parsed.page()).isEqualTo(2);
        assertThat(parsed.size()).isEqualTo(50);

        // q > 200 code points
        assertThatThrownBy(() -> validator.parse("a".repeat(201), null, null, null, null, false))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).fieldErrors()).containsKey("q"));

        // Missing required type
        assertThatThrownBy(() -> validator.parse(null, null, null, null, null, true))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).fieldErrors()).containsKey("type"));

        // Invalid enum, page, size, uuid
        assertThatThrownBy(() -> validator.parse(null, "MOVIE", null, null, null, false))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).fieldErrors()).containsKey("type"));
        assertThatThrownBy(() -> validator.parse(null, null, null, "-1", null, false))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).fieldErrors()).containsKey("page"));
        assertThatThrownBy(() -> validator.parse(null, null, null, "0", "0", false))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).fieldErrors()).containsKey("size"));
        assertThatThrownBy(() -> validator.parse(null, null, null, "0", "51", false))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).fieldErrors()).containsKey("size"));
        assertThatThrownBy(() -> validator.uuid("not-a-uuid", "id"))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).fieldErrors()).containsKey("id"));
    }

    @Test
    void thumbnailServiceLoadsValidImagesAndBlocksTraversalAndBadSignatures(@TempDir Path tempDir) throws Exception {
        Path mediaRoot = Files.createDirectory(tempDir.resolve("media"));
        Path outside = tempDir.resolve("secret.png");
        byte[] validPng = {(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00};
        byte[] validJpeg = {(byte) 0xff, (byte) 0xd8, (byte) 0xff, (byte) 0xe0};
        byte[] validWebp = {'R', 'I', 'F', 'F', 0, 0, 0, 0, 'W', 'E', 'B', 'P'};

        Files.write(outside, validPng);
        Files.write(mediaRoot.resolve("cover.png"), validPng);
        Files.write(mediaRoot.resolve("cover.jpg"), validJpeg);
        Files.write(mediaRoot.resolve("cover.webp"), validWebp);
        Files.write(mediaRoot.resolve("forged.png"), validJpeg);
        Files.writeString(mediaRoot.resolve("notes.txt"), "hello");

        var repo = mock(CatalogQueryRepository.class);
        var props = new MediaProperties();
        props.setRoot(mediaRoot);
        var service = new ThumbnailService(repo, props);

        UUID id = UUID.randomUUID();
        when(repo.findAvailableThumbnailPath(id)).thenReturn(Optional.of("cover.png"));
        var png = service.load(id);
        assertThat(png.contentType()).isEqualTo(MediaType.IMAGE_PNG);
        assertThat(png.bytes()).isEqualTo(validPng);

        when(repo.findAvailableThumbnailPath(id)).thenReturn(Optional.of("cover.jpg"));
        assertThat(service.load(id).contentType()).isEqualTo(MediaType.IMAGE_JPEG);

        when(repo.findAvailableThumbnailPath(id)).thenReturn(Optional.of("cover.webp"));
        assertThat(service.load(id).contentType()).isEqualTo(MediaType.parseMediaType("image/webp"));

        // Path traversal rejected
        when(repo.findAvailableThumbnailPath(id)).thenReturn(Optional.of("../secret.png"));
        assertThatThrownBy(() -> service.load(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).code()).isEqualTo(ErrorCode.CONTENT_UNAVAILABLE));

        // Absolute path rejected
        when(repo.findAvailableThumbnailPath(id)).thenReturn(Optional.of(outside.toAbsolutePath().toString()));
        assertThatThrownBy(() -> service.load(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).code()).isEqualTo(ErrorCode.CONTENT_UNAVAILABLE));

        // Forged signature rejected
        when(repo.findAvailableThumbnailPath(id)).thenReturn(Optional.of("forged.png"));
        assertThatThrownBy(() -> service.load(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).code()).isEqualTo(ErrorCode.CONTENT_UNAVAILABLE));

        // Disallowed extension rejected
        when(repo.findAvailableThumbnailPath(id)).thenReturn(Optional.of("notes.txt"));
        assertThatThrownBy(() -> service.load(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).code()).isEqualTo(ErrorCode.CONTENT_UNAVAILABLE));

        // Missing file rejected
        when(repo.findAvailableThumbnailPath(id)).thenReturn(Optional.of("missing.png"));
        assertThatThrownBy(() -> service.load(id))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).code()).isEqualTo(ErrorCode.CONTENT_UNAVAILABLE));
    }
}
