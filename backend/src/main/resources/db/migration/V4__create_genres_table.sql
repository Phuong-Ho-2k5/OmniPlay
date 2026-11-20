CREATE TABLE genres (
    genre_id UUID NOT NULL DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    CONSTRAINT genres_pkey PRIMARY KEY (genre_id),
    CONSTRAINT genres_name_key UNIQUE (name),
    CHECK (char_length(btrim(name)) > 0)
);
