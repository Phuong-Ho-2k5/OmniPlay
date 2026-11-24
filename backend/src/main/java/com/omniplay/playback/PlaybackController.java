package com.omniplay.playback;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.dto.response.PlaybackMetadataResponse;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.file.Path;
import java.util.UUID;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

@RestController
@RequestMapping("/media")
public class PlaybackController {
    private static final int STREAM_BUFFER_BYTES = 64 * 1024;

    private final PlaybackService playback;
    private final MediaStreamService stream;
    private final CatalogInputValidator input;

    public PlaybackController(PlaybackService playback, MediaStreamService stream, CatalogInputValidator input) {
        this.playback = playback;
        this.stream = stream;
        this.input = input;
    }

    @GetMapping("/{id}/playback")
    public PlaybackMetadataResponse metadata(@AuthenticationPrincipal Jwt jwt, @PathVariable String id) {
        return playback.metadata(UUID.fromString(jwt.getSubject()), input.uuid(id, "id"));
    }

    @GetMapping("/{id}/stream")
    public ResponseEntity<StreamingResponseBody> stream(@PathVariable String id,
            @RequestHeader(value = HttpHeaders.RANGE, required = false) String rangeHeader) {
        UUID mediaId = input.uuid(id, "id");
        var plan = stream.prepare(mediaId, rangeHeader);
        return switch (plan) {
            case MediaStreamService.StreamPlan.Full full -> ResponseEntity.ok()
                    .cacheControl(CacheControl.noStore().cachePrivate())
                    .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                    .contentType(full.contentType())
                    .contentLength(full.totalLength())
                    .body(copyRange(full.path(), 0, full.totalLength()));
            case MediaStreamService.StreamPlan.Partial partial -> ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
                    .cacheControl(CacheControl.noStore().cachePrivate())
                    .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                    .header(HttpHeaders.CONTENT_RANGE,
                            "bytes " + partial.start() + "-" + partial.end() + "/" + partial.totalLength())
                    .contentType(partial.contentType())
                    .contentLength(partial.length())
                    .body(copyRange(partial.path(), partial.start(), partial.length()));
            case MediaStreamService.StreamPlan.Unsatisfiable unsat -> ResponseEntity
                    .status(HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
                    .cacheControl(CacheControl.noStore().cachePrivate())
                    .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                    .header(HttpHeaders.CONTENT_RANGE, "bytes */" + unsat.totalLength())
                    .build();
        };
    }

    private StreamingResponseBody copyRange(Path path, long start, long length) {
        return outputStream -> {
            byte[] buffer = new byte[STREAM_BUFFER_BYTES];
            long remaining = length;
            try (var file = new RandomAccessFile(path.toFile(), "r")) {
                file.seek(start);
                while (remaining > 0) {
                    int read = file.read(buffer, 0, (int) Math.min(buffer.length, remaining));
                    if (read < 0) break;
                    outputStream.write(buffer, 0, read);
                    remaining -= read;
                }
                outputStream.flush();
            } catch (IOException ignored) {
                // Client disconnect / seek abort while streaming is normal for media players.
            }
        };
    }
}
