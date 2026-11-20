CREATE TABLE quest_eligible_media (
    daily_quest_id UUID NOT NULL,
    media_id UUID NOT NULL,
    CONSTRAINT quest_eligible_media_pkey PRIMARY KEY (daily_quest_id, media_id)
);
