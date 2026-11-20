CREATE TABLE badges (
    badge_id UUID NOT NULL DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    xp_threshold INT NOT NULL,
    CONSTRAINT badges_pkey PRIMARY KEY (badge_id),
    CONSTRAINT badges_name_key UNIQUE (name),
    CONSTRAINT badges_xp_threshold_key UNIQUE (xp_threshold),
    CHECK (xp_threshold IN (10,50,100)),
    CHECK (char_length(btrim(name)) > 0)
);
