package com.omniplay.config;

import java.nio.file.Path;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "omniplay.media")
public class MediaProperties {
    private Path root = Path.of("./media");
    public Path getRoot() { return root; }
    public void setRoot(Path root) { this.root = root; }
}
