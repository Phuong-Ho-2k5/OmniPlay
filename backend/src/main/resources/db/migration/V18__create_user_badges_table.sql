CREATE TABLE user_badges (
    user_id UUID NOT NULL,
    badge_id UUID NOT NULL,
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT user_badges_pkey PRIMARY KEY (user_id, badge_id)
);
