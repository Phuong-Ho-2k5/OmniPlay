CREATE TABLE playback_segments (
    segment_id UUID NOT NULL DEFAULT gen_random_uuid(),
    progress_id UUID NOT NULL,
    attempt_id UUID NOT NULL,
    event_seq BIGINT NOT NULL,
    quest_set_id UUID,
    start_second NUMERIC(12,3) NOT NULL,
    end_second NUMERIC(12,3) NOT NULL,
    played_from TIMESTAMPTZ NOT NULL,
    played_to TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT playback_segments_pkey PRIMARY KEY (segment_id),
    CONSTRAINT playback_segments_attempt_id_event_seq_key UNIQUE (attempt_id, event_seq),
    CHECK (event_seq >= 0),
    CHECK (start_second >= 0 AND end_second > start_second),
    CHECK (played_to > played_from AND received_at >= played_to)
);
