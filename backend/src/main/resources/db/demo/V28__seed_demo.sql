-- OPT-IN: run with profiles local,demo. Never include this location in production.
-- Demo-only password for all three accounts: OmniPlayDemo!2026 (BCrypt cost 10).
-- Authentication endpoints are implemented on Day 4; these are database fixtures.
INSERT INTO users (user_id, email, password_hash, display_name) VALUES
('30000000-0000-4000-8000-000000000001', 'normal@demo.omniplay.local', '$2a$10$7WUDQMn6x1piT7brzwkzBOSvnJSc.48Msbs7cQpONdxE6RR1FMAhC', 'Demo mới'),
('30000000-0000-4000-8000-000000000002', 'saved@demo.omniplay.local', '$2a$10$7WUDQMn6x1piT7brzwkzBOSvnJSc.48Msbs7cQpONdxE6RR1FMAhC', 'Demo đã lưu'),
('30000000-0000-4000-8000-000000000003', 'cleanup@demo.omniplay.local', '$2a$10$7WUDQMn6x1piT7brzwkzBOSvnJSc.48Msbs7cQpONdxE6RR1FMAhC', 'Demo dọn playlist');

-- Paths/durations must match demo/media-manifest.json and generated files under media/.
INSERT INTO media (media_id, title, media_type, duration_seconds, file_path, thumbnail_path, description) VALUES
('20000000-0000-4000-8000-000000000001', 'Video mẫu 01 — Khám phá', 'VIDEO', 12, 'demo/video-01.mp4', 'demo/video-01.jpg', 'Video kiểm thử tổng hợp có hình chuyển động và âm thanh.'),
('20000000-0000-4000-8000-000000000002', 'Video mẫu 02 — Công nghệ', 'VIDEO', 16, 'demo/video-02.mp4', 'demo/video-02.jpg', 'Video kiểm thử tổng hợp, dùng thử phát và tua.'),
('20000000-0000-4000-8000-000000000003', 'Video mẫu 03 — Học tập', 'VIDEO', 20, 'demo/video-03.mp4', 'demo/video-03.jpg', 'Video kiểm thử tổng hợp, dùng kiểm tra độ phủ phát.'),
('20000000-0000-4000-8000-000000000004', 'Nhạc mẫu 01 — Thư giãn', 'MUSIC', 18, 'demo/music-01.mp3', 'demo/music-01.jpg', 'Âm thanh tổng hợp dùng kiểm thử player và playlist.'),
('20000000-0000-4000-8000-000000000005', 'Nhạc mẫu 02 — Tập trung', 'MUSIC', 22, 'demo/music-02.mp3', 'demo/music-02.jpg', 'Âm thanh tổng hợp dùng kiểm thử Next và Skip.'),
('20000000-0000-4000-8000-000000000006', 'Nhạc mẫu 03 — Khám phá', 'MUSIC', 26, 'demo/music-03.mp3', 'demo/music-03.jpg', 'Âm thanh tổng hợp dùng kiểm thử hàng đợi.'),
('20000000-0000-4000-8000-000000000007', 'Podcast mẫu 01 — Công nghệ', 'PODCAST', 24, 'demo/podcast-01.mp3', 'demo/podcast-01.jpg', 'Âm thanh giả lập podcast dùng kiểm thử phiên nghe riêng.'),
('20000000-0000-4000-8000-000000000008', 'Podcast mẫu 02 — Học tập', 'PODCAST', 30, 'demo/podcast-02.mp3', 'demo/podcast-02.jpg', 'Âm thanh giả lập podcast dùng kiểm thử tiếp tục nghe.');

INSERT INTO media_genres (media_id, genre_id) VALUES
('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001'),
('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000003'),
('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000004'),
('20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000002'),
('20000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000002'),
('20000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000004'),
('20000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000001'),
('20000000-0000-4000-8000-000000000007', '10000000-0000-4000-8000-000000000003'),
('20000000-0000-4000-8000-000000000008', '10000000-0000-4000-8000-000000000004');

INSERT INTO posts (post_id, title, content) VALUES
('70000000-0000-4000-8000-000000000001', 'Chào mừng đến với OmniPlay', 'OmniPlay kết hợp xem video, nghe nhạc, podcast và đọc bài viết. Đây là bài viết mẫu được lưu trực tiếp trong PostgreSQL. Bạn có thể dùng bài này để kiểm tra danh mục Post và lưu đọc sau. Post không tham gia Quest xem hoặc nghe.'),
('70000000-0000-4000-8000-000000000002', 'Cách dùng bộ dữ liệu demo', 'Tài khoản normal chưa lưu nội dung. Tài khoản saved đã lưu đủ tám media và một Post. Tài khoản cleanup có playlist ba bài nhạc, trong đó bài đầu có năm Skip để kiểm tra gợi ý tại Skip thứ sáu. File media là tín hiệu tổng hợp phục vụ kiểm thử, có thể tạo lại bằng script của dự án.');

INSERT INTO favorites (user_id, media_id)
SELECT '30000000-0000-4000-8000-000000000002', media_id FROM media
WHERE media_id IN (
    '20000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000004',
    '20000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000006',
    '20000000-0000-4000-8000-000000000007', '20000000-0000-4000-8000-000000000008'
);

INSERT INTO post_favorites (user_id, post_id) VALUES
('30000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000001');

INSERT INTO playlists (playlist_id, user_id, name, creation_name) VALUES
('40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'Demo — Dọn playlist', 'Demo — Dọn playlist');

INSERT INTO playlist_items (playlist_item_id, playlist_id, media_id, position, skip_count) VALUES
('41000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000004', 0, 5),
('41000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000005', 1, 0),
('41000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000006', 2, 0);

-- No pre-issued daily quests, XP, progress or auth sessions: later API tests start clean.
