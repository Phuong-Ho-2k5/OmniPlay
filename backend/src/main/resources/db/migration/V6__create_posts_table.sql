CREATE TABLE posts (
    post_id UUID NOT NULL DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT posts_pkey PRIMARY KEY (post_id),
    CHECK (char_length(btrim(title)) > 0),
    CHECK (char_length(btrim(content)) > 0)
);
