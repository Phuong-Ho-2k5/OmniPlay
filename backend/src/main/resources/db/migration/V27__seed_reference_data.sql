-- Shared MVP configuration. Stable IDs are also used by the optional demo seed.
INSERT INTO genres (genre_id, name) VALUES
('10000000-0000-4000-8000-000000000001', 'Khám phá'),
('10000000-0000-4000-8000-000000000002', 'Thư giãn'),
('10000000-0000-4000-8000-000000000003', 'Công nghệ'),
('10000000-0000-4000-8000-000000000004', 'Học tập');

-- All templates retain genre_id NULL. Updated reward rule: ANY 10 XP/item, SAVED 15 XP/item.
INSERT INTO quest_templates
    (template_id, code, title, media_type, genre_id, source_scope, is_fixed, target_count, xp_reward)
VALUES
('50000000-0000-4000-8000-000000000001', 'Q01', 'Hoàn thành 1 video', 'VIDEO', NULL, 'ANY', TRUE, 1, 10),
('50000000-0000-4000-8000-000000000002', 'Q02', 'Hoàn thành 1 bài nhạc', 'MUSIC', NULL, 'ANY', TRUE, 1, 10),
('50000000-0000-4000-8000-000000000003', 'Q03', 'Quay lại 1 video đã lưu', 'VIDEO', NULL, 'SAVED', FALSE, 1, 15),
('50000000-0000-4000-8000-000000000004', 'Q04', 'Quay lại 1 podcast đã lưu', 'PODCAST', NULL, 'SAVED', FALSE, 1, 15),
('50000000-0000-4000-8000-000000000005', 'Q05', 'Hoàn thành 2 media đã lưu khác nhau', NULL, NULL, 'SAVED', FALSE, 2, 30),
('50000000-0000-4000-8000-000000000006', 'Q06', 'Quay lại 1 bài nhạc đã lưu', 'MUSIC', NULL, 'SAVED', FALSE, 1, 15),
('50000000-0000-4000-8000-000000000007', 'Q07', 'Hoàn thành 1 podcast', 'PODCAST', NULL, 'ANY', FALSE, 1, 10),
('50000000-0000-4000-8000-000000000008', 'Q08', 'Hoàn thành 2 video khác nhau', 'VIDEO', NULL, 'ANY', FALSE, 2, 20),
('50000000-0000-4000-8000-000000000009', 'Q09', 'Hoàn thành 2 bài nhạc khác nhau', 'MUSIC', NULL, 'ANY', FALSE, 2, 20),
('50000000-0000-4000-8000-000000000010', 'Q10', 'Hoàn thành 3 media khác nhau', NULL, NULL, 'ANY', FALSE, 3, 30);

INSERT INTO badges (badge_id, name, description, xp_threshold) VALUES
('60000000-0000-4000-8000-000000000001', 'Khởi đầu', 'Nhận tổng cộng 10 XP từ Daily Quest.', 10),
('60000000-0000-4000-8000-000000000002', 'Duy trì', 'Nhận tổng cộng 50 XP từ Daily Quest.', 50),
('60000000-0000-4000-8000-000000000003', 'Tích lũy', 'Nhận tổng cộng 100 XP từ Daily Quest.', 100);
