CREATE TABLE post_favorites (
    user_id UUID NOT NULL,
    post_id UUID NOT NULL,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT post_favorites_pkey PRIMARY KEY (user_id, post_id)
);
