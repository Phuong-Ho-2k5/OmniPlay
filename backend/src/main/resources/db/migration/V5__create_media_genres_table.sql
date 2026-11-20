CREATE TABLE media_genres (
    media_id UUID NOT NULL,
    genre_id UUID NOT NULL,
    CONSTRAINT media_genres_pkey PRIMARY KEY (media_id, genre_id)
);
