CREATE TABLE media (
    media_id UUID NOT NULL DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    media_type media_kind NOT NULL,
    duration_seconds INT NOT NULL,
    file_path TEXT NOT NULL,
    thumbnail_path TEXT,
    description TEXT,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT media_pkey PRIMARY KEY (media_id),
    CHECK (char_length(btrim(title)) > 0),
    CHECK (duration_seconds > 0),
    CHECK (char_length(btrim(file_path)) > 0)
);
