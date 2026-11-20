CREATE TABLE auth_sessions (
    auth_session_id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    current_token_hash CHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    rotated_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    CONSTRAINT auth_sessions_pkey PRIMARY KEY (auth_session_id),
    CONSTRAINT auth_sessions_current_token_hash_key UNIQUE (current_token_hash),
    CHECK (current_token_hash ~ '^[0-9a-f]{64}$'),
    CHECK (expires_at = created_at + interval '168 hours'),
    CHECK (rotated_at IS NULL OR (rotated_at >= created_at AND rotated_at < expires_at)),
    CHECK (revoked_at IS NULL OR revoked_at >= created_at)
);
