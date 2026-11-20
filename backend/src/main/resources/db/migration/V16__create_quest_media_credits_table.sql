CREATE TABLE quest_media_credits (
    daily_quest_id UUID NOT NULL,
    media_id UUID NOT NULL,
    credited_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT quest_media_credits_pkey PRIMARY KEY (daily_quest_id, media_id)
);
