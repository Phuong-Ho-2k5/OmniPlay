CREATE TABLE auth_refresh_history (
    auth_session_id UUID NOT NULL,
    token_hash CHAR(64) NOT NULL,
    consumed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT auth_refresh_history_pkey PRIMARY KEY (auth_session_id, token_hash),
    CHECK (token_hash ~ '^[0-9a-f]{64}$')
);
