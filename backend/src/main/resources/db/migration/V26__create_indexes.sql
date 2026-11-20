-- All 25 additional indexes. PK/UNIQUE indexes are created with their table constraints.

CREATE INDEX ix_media_1 ON media (is_available, media_type, created_at DESC, media_id DESC);
CREATE INDEX ix_media_genres_1 ON media_genres (genre_id, media_id);
CREATE INDEX ix_posts_1 ON posts (is_available, created_at DESC, post_id DESC);
CREATE INDEX ix_favorites_1 ON favorites (user_id, saved_at DESC, media_id DESC);
CREATE INDEX ix_favorites_2 ON favorites (media_id);
CREATE INDEX ix_playlists_1 ON playlists (user_id, created_at DESC, playlist_id DESC);
CREATE INDEX ix_playlist_items_1 ON playlist_items (media_id);
CREATE INDEX ix_playlist_items_2 ON playlist_items (playlist_id, skip_count, playlist_item_id) WHERE skip_count >= 6 AND suggestion_dismissed = FALSE;
CREATE INDEX ix_playback_progress_1 ON playback_progress (media_id);
CREATE INDEX ix_playback_segments_1 ON playback_segments (progress_id, start_second, end_second);
CREATE INDEX ix_playback_segments_2 ON playback_segments (quest_set_id, progress_id, start_second, end_second);
CREATE INDEX ix_listening_sessions_1 ON listening_sessions (current_media_id) WHERE current_media_id IS NOT NULL;
CREATE INDEX ix_listening_queue_items_1 ON listening_queue_items (media_id);
CREATE INDEX ix_quest_templates_1 ON quest_templates (genre_id) WHERE genre_id IS NOT NULL;
CREATE INDEX ix_daily_quests_1 ON daily_quests (template_id);
CREATE INDEX ix_quest_media_credits_1 ON quest_media_credits (media_id);
CREATE INDEX ix_user_badges_1 ON user_badges (badge_id);
CREATE INDEX ix_post_favorites_1 ON post_favorites (user_id, saved_at DESC, post_id DESC);
CREATE INDEX ix_post_favorites_2 ON post_favorites (post_id);
CREATE INDEX ix_auth_sessions_1 ON auth_sessions (user_id);
CREATE INDEX ix_auth_sessions_2 ON auth_sessions (expires_at);
CREATE INDEX ix_playback_attempts_1 ON playback_attempts (user_id);
CREATE INDEX ix_playback_attempts_2 ON playback_attempts (media_id);
CREATE INDEX ix_playback_attempts_3 ON playback_attempts (playlist_item_id) WHERE playlist_item_id IS NOT NULL;
CREATE INDEX ix_quest_eligible_media_1 ON quest_eligible_media (media_id);
