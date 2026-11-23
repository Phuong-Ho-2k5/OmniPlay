package com.omniplay.catalog;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.config.MediaProperties;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;

@Service
public class ThumbnailService {
    private static final int MAX_IMAGE_BYTES = 10 * 1024 * 1024;
    private final CatalogQueryRepository repository;
    private final MediaProperties properties;
    public ThumbnailService(CatalogQueryRepository repository, MediaProperties properties) {
        this.repository = repository;
        this.properties = properties;
    }

    public Thumbnail load(UUID mediaId) {
        String relative = repository.findAvailableThumbnailPath(mediaId)
                .orElseThrow(() -> new ApiException(ErrorCode.CONTENT_UNAVAILABLE));
        try {
            Path root = properties.getRoot().toRealPath();
            Path supplied = Path.of(relative);
            if (supplied.isAbsolute()) throw new ApiException(ErrorCode.CONTENT_UNAVAILABLE);
            Path path = root.resolve(supplied).normalize().toRealPath();
            if (!path.startsWith(root) || !Files.isRegularFile(path) || Files.size(path) > MAX_IMAGE_BYTES) {
                throw new ApiException(ErrorCode.CONTENT_UNAVAILABLE);
            }
            String name = path.getFileName().toString().toLowerCase(Locale.ROOT);
            MediaType type;
            if (name.endsWith(".jpg") || name.endsWith(".jpeg")) type = MediaType.IMAGE_JPEG;
            else if (name.endsWith(".png")) type = MediaType.IMAGE_PNG;
            else if (name.endsWith(".webp")) type = MediaType.parseMediaType("image/webp");
            else throw new ApiException(ErrorCode.CONTENT_UNAVAILABLE);
            byte[] bytes;
            try (var stream = Files.newInputStream(path)) {
                bytes = stream.readNBytes(MAX_IMAGE_BYTES + 1);
            }
            if (bytes.length > MAX_IMAGE_BYTES || !matchesSignature(bytes, type)) {
                throw new ApiException(ErrorCode.CONTENT_UNAVAILABLE);
            }
            return new Thumbnail(bytes, type);
        } catch (IOException | IllegalArgumentException | SecurityException e) {
            throw new ApiException(ErrorCode.CONTENT_UNAVAILABLE);
        }
    }

    private boolean matchesSignature(byte[] bytes, MediaType type) {
        if (type.equals(MediaType.IMAGE_JPEG)) {
            return bytes.length >= 3 && (bytes[0] & 0xff) == 0xff
                    && (bytes[1] & 0xff) == 0xd8 && (bytes[2] & 0xff) == 0xff;
        }
        if (type.equals(MediaType.IMAGE_PNG)) {
            byte[] signature = {(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};
            return bytes.length >= signature.length
                    && java.util.Arrays.equals(signature, java.util.Arrays.copyOf(bytes, signature.length));
        }
        return bytes.length >= 12 && bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == 'F'
                && bytes[8] == 'W' && bytes[9] == 'E' && bytes[10] == 'B' && bytes[11] == 'P';
    }

    public record Thumbnail(byte[] bytes, MediaType contentType) {}
}
