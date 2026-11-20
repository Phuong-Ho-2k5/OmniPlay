CREATE TABLE playback_attempts (
    attempt_id UUID NOT NULL,
    user_id UUID NOT NULL,
    media_id UUID NOT NULL,
    playlist_item_id UUID,
    initial_playlist_item_id UUID,
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    skip_recorded BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT playback_attempts_pkey PRIMARY KEY (attempt_id),
    CHECK (playlist_item_id IS NULL OR (initial_playlist_item_id IS NOT NULL AND playlist_item_id = initial_playlist_item_id))
);
