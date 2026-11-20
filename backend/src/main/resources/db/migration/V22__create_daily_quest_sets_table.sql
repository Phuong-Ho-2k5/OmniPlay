CREATE TABLE daily_quest_sets (
    quest_set_id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    quest_date DATE NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT daily_quest_sets_pkey PRIMARY KEY (quest_set_id),
    CONSTRAINT daily_quest_sets_user_id_quest_date_key UNIQUE (user_id, quest_date),
    CONSTRAINT daily_quest_sets_quest_set_id_user_id_quest_date_key UNIQUE (quest_set_id, user_id, quest_date),
    CHECK (quest_date = (issued_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date),
    CHECK (expires_at = ((quest_date + 1)::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh')),
    CHECK (expires_at > issued_at)
);
