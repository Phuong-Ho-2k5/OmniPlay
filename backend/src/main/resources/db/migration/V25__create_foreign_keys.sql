-- All 34 foreign keys; all tables and their PK/UNIQUE constraints already exist.

ALTER TABLE media_genres ADD CONSTRAINT fk01
    FOREIGN KEY (media_id) REFERENCES media (media_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE media_genres ADD CONSTRAINT fk02
    FOREIGN KEY (genre_id) REFERENCES genres (genre_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE auth_refresh_history ADD CONSTRAINT fk03
    FOREIGN KEY (auth_session_id) REFERENCES auth_sessions (auth_session_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE user_badges ADD CONSTRAINT fk04
    FOREIGN KEY (badge_id) REFERENCES badges (badge_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE post_favorites ADD CONSTRAINT fk05
    FOREIGN KEY (post_id) REFERENCES posts (post_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE playlist_items ADD CONSTRAINT fk06
    FOREIGN KEY (playlist_id) REFERENCES playlists (playlist_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE daily_quests ADD CONSTRAINT fk07
    FOREIGN KEY (quest_set_id, user_id, quest_date) REFERENCES daily_quest_sets (quest_set_id, user_id, quest_date)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE playback_segments ADD CONSTRAINT fk08
    FOREIGN KEY (attempt_id) REFERENCES playback_attempts (attempt_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE auth_sessions ADD CONSTRAINT fk09
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE listening_queue_items ADD CONSTRAINT fk10
    FOREIGN KEY (session_id) REFERENCES listening_sessions (session_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE quest_eligible_media ADD CONSTRAINT fk11
    FOREIGN KEY (daily_quest_id) REFERENCES daily_quests (daily_quest_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE post_favorites ADD CONSTRAINT fk12
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE playback_segments ADD CONSTRAINT fk13
    FOREIGN KEY (progress_id) REFERENCES playback_progress (progress_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE playlists ADD CONSTRAINT fk14
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE playback_progress ADD CONSTRAINT fk15
    FOREIGN KEY (media_id) REFERENCES media (media_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE listening_queue_items ADD CONSTRAINT fk16
    FOREIGN KEY (media_id) REFERENCES media (media_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE daily_quests ADD CONSTRAINT fk17
    FOREIGN KEY (template_id) REFERENCES quest_templates (template_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE quest_media_credits ADD CONSTRAINT fk18
    FOREIGN KEY (daily_quest_id) REFERENCES daily_quests (daily_quest_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE user_badges ADD CONSTRAINT fk19
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE playlist_items ADD CONSTRAINT fk20
    FOREIGN KEY (media_id) REFERENCES media (media_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE playback_attempts ADD CONSTRAINT fk21
    FOREIGN KEY (media_id) REFERENCES media (media_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE listening_sessions ADD CONSTRAINT fk22
    FOREIGN KEY (current_media_id) REFERENCES media (media_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE favorites ADD CONSTRAINT fk23
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE favorites ADD CONSTRAINT fk24
    FOREIGN KEY (media_id) REFERENCES media (media_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE quest_templates ADD CONSTRAINT fk25
    FOREIGN KEY (genre_id) REFERENCES genres (genre_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE playback_attempts ADD CONSTRAINT fk26
    FOREIGN KEY (playlist_item_id) REFERENCES playlist_items (playlist_item_id)
    ON DELETE SET NULL ON UPDATE NO ACTION;

ALTER TABLE playback_segments ADD CONSTRAINT fk27
    FOREIGN KEY (quest_set_id) REFERENCES daily_quest_sets (quest_set_id)
    ON DELETE SET NULL ON UPDATE NO ACTION;

ALTER TABLE playback_progress ADD CONSTRAINT fk28
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE quest_eligible_media ADD CONSTRAINT fk29
    FOREIGN KEY (media_id) REFERENCES media (media_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE playback_attempts ADD CONSTRAINT fk30
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE quest_media_credits ADD CONSTRAINT fk31
    FOREIGN KEY (media_id) REFERENCES media (media_id)
    ON DELETE RESTRICT ON UPDATE NO ACTION;

ALTER TABLE daily_quests ADD CONSTRAINT fk32
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE listening_sessions ADD CONSTRAINT fk33
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE daily_quest_sets ADD CONSTRAINT fk34
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE NO ACTION;
