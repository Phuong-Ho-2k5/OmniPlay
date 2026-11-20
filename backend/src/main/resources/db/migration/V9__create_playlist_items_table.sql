CREATE TABLE playlist_items (
    playlist_item_id UUID NOT NULL DEFAULT gen_random_uuid(),
    playlist_id UUID NOT NULL,
    media_id UUID NOT NULL,
    position INT NOT NULL,
    skip_count INT NOT NULL DEFAULT 0,
    suggestion_dismissed BOOLEAN NOT NULL DEFAULT FALSE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT playlist_items_pkey PRIMARY KEY (playlist_item_id),
    CONSTRAINT playlist_items_playlist_id_media_id_key UNIQUE (playlist_id, media_id),
    CONSTRAINT playlist_items_playlist_id_position_key UNIQUE (playlist_id, position),
    CHECK (position >= 0),
    CHECK (skip_count >= 0)
);
