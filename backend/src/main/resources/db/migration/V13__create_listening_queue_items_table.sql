CREATE TABLE listening_queue_items (
    queue_item_id UUID NOT NULL DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    media_id UUID NOT NULL,
    position INT NOT NULL,
    CONSTRAINT listening_queue_items_pkey PRIMARY KEY (queue_item_id),
    CONSTRAINT listening_queue_items_session_id_position_key UNIQUE (session_id, position),
    CHECK (position >= 0)
);
