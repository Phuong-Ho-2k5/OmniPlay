CREATE TABLE listening_sessions (
    session_id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    session_type listening_kind NOT NULL,
    current_media_id UUID,
    position_seconds NUMERIC(12,3) NOT NULL DEFAULT 0,
    is_paused BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT listening_sessions_pkey PRIMARY KEY (session_id),
    CONSTRAINT listening_sessions_user_id_session_type_key UNIQUE (user_id, session_type),
    CHECK (position_seconds >= 0),
    CHECK (current_media_id IS NOT NULL OR (position_seconds = 0 AND is_paused = TRUE))
);
