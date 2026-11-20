CREATE TABLE users (
    user_id UUID NOT NULL DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    total_xp INT NOT NULL DEFAULT 0,
    level INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT users_pkey PRIMARY KEY (user_id),
    CONSTRAINT users_email_key UNIQUE (email),
    CHECK (email = lower(btrim(email)) AND char_length(email) BETWEEN 3 AND 255),
    CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 100),
    CHECK (char_length(password_hash) > 0),
    CHECK (total_xp >= 0 AND level = 1 + total_xp / 100)
);
