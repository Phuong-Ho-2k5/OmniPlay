CREATE TABLE favorites (
    user_id UUID NOT NULL,
    media_id UUID NOT NULL,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT favorites_pkey PRIMARY KEY (user_id, media_id)
);
