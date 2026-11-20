CREATE TABLE quest_templates (
    template_id UUID NOT NULL DEFAULT gen_random_uuid(),
    code VARCHAR(3) NOT NULL,
    title VARCHAR(160) NOT NULL,
    media_type media_kind,
    genre_id UUID,
    source_scope quest_scope NOT NULL,
    is_fixed BOOLEAN NOT NULL,
    target_count INT NOT NULL,
    xp_reward INT NOT NULL DEFAULT 10,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT quest_templates_pkey PRIMARY KEY (template_id),
    CONSTRAINT quest_templates_code_key UNIQUE (code),
    CHECK (code ~ '^Q(0[1-9]|10)$'),
    CHECK (is_fixed = (code IN ('Q01','Q02'))),
    CHECK (target_count > 0),
    CHECK (xp_reward = target_count * CASE source_scope WHEN 'SAVED' THEN 15 ELSE 10 END)
);
