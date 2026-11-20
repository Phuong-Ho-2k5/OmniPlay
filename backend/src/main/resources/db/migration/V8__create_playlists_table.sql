CREATE TABLE playlists (
    playlist_id UUID NOT NULL,
    user_id UUID NOT NULL,
    name VARCHAR(120) NOT NULL,
    creation_name VARCHAR(120) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT playlists_pkey PRIMARY KEY (playlist_id),
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 120),
    CHECK (creation_name = btrim(creation_name) AND char_length(creation_name) BETWEEN 1 AND 120),
    CHECK (updated_at >= created_at)
);
