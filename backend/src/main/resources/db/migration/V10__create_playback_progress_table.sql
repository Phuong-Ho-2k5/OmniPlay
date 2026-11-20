CREATE TABLE playback_progress (
    progress_id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    media_id UUID NOT NULL,
    resume_position_seconds NUMERIC(12,3) NOT NULL DEFAULT 0,
    covered_seconds NUMERIC(12,3) NOT NULL DEFAULT 0,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT playback_progress_pkey PRIMARY KEY (progress_id),
    CONSTRAINT playback_progress_user_id_media_id_key UNIQUE (user_id, media_id),
    CHECK (resume_position_seconds >= 0 AND covered_seconds >= 0)
);
