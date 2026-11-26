# OmniPlay

OmniPlay là ứng dụng Android xây dựng bằng Flutter và Spring Boot, hướng tới xem video, nghe nhạc, podcast và đọc bài viết. Metadata lưu trong PostgreSQL; file media nằm trên máy chủ.

## Chức năng hiện có

- Đăng ký tài khoản với validation, chuẩn hóa email và mật khẩu BCrypt.
- Đăng nhập, cấp JWT và refresh token, lưu AuthSession trong PostgreSQL.
- Refresh rotation, phát hiện dùng lại token cũ và đăng xuất theo từng phiên.
- Xác thực Bearer token, chuẩn hóa lỗi API và cung cấp health endpoint.
- Biểu mẫu Flutter theo MVVM, hiển thị lỗi theo trường và lưu cặp token bằng secure storage.
- Khôi phục phiên khi mở app, điều phối refresh chung và xóa phiên local khi đăng xuất offline.
- Schema PostgreSQL, migration Flyway, danh mục tham chiếu và dữ liệu demo.
- Danh mục bốn loại nội dung, tìm tiêu đề, lọc loại/thể loại, phân trang và chi tiết có xác thực.
- Màn Khám phá Flutter, đọc chi tiết Post, ảnh bìa có JWT và xử lý rỗng/lỗi/tải thêm.
- Playback metadata (`GET /media/{id}/playback`) và stream media có xác thực JWT hỗ trợ HTTP Range (`200`/`206`/`416`).
- Ghi nhận lượt phát (`POST /me/playback-attempts`), báo cáo tiến độ/segment (`PUT /me/progress/{mediaId}`) với hợp nhất đoạn trùng theo trục media và ngưỡng hoàn thành 90%, cùng hai phiên nghe Nhạc/Podcast độc lập (`GET`/`PUT /me/listening-sessions/{type}`).
- Quản lý danh sách Đã lưu (`GET /me/saved`, `PUT /me/saved/{id}`) hợp nhất media và bài viết theo `savedAt` giảm dần, hỗ trợ bỏ lưu cả nội dung ngừng phục vụ.
- Quản lý playlist cá nhân (`GET`/`POST /me/playlists`, `GET`/`PATCH`/`DELETE /me/playlists/{id}`) và bài nhạc trong playlist (`PUT`/`DELETE /me/playlists/{id}/items/{mediaId}`) với idempotency theo `requestId`, chống trùng bài, chỉ nhận nhạc khả dụng, gỡ bài giữ nguyên media gốc và xác nhận trước khi xóa.
- Trình phát trong Flutter (`video_player` cho Video, `just_audio` dùng chung qua `PlayerCoordinator` cho Nhạc/Podcast) hỗ trợ Play/Pause/Seek, tự refresh token khi 401, theo dõi độ phủ phát thực tế tách biệt với vị trí thanh tua, báo cáo theo nhịp 15 giây, khôi phục tiến độ từ máy chủ, xử lý đồng bộ lại khi mất mạng, chuyển phiên Nhạc ↔ Podcast ở trạng thái tạm dừng, phát playlist theo hàng đợi với nút Previous/Next (khóa Next ở cuối và tự chuyển bài khi phát hết), Mini Player xuyên suốt khi chuyển màn, điều hướng ba tab Khám phá / Đã lưu / Playlist và dừng phát/lưu tiến độ khi rời màn, xuống nền hoặc đăng xuất.

Sau đăng nhập, ứng dụng mở Khám phá, Đã lưu và Playlist, cho phép phát Video, Nhạc, Podcast, đọc Post, lưu/bỏ lưu nội dung, quản lý playlist kèm thêm/gỡ bài và phát hàng đợi, và điều khiển hai phiên nghe qua Mini Player. Skip/dọn playlist, Quest, Mystery Box và Hồ sơ nằm ở các hạng mục tiếp theo.

## Công nghệ

| Thành phần | Công nghệ |
| --- | --- |
| Android | Flutter 3.50.1, Dart 3.14.0 |
| Backend | Java 21, Spring Boot 4.1.1, Maven Wrapper |
| Bảo mật | Spring Security, JWT HS256, BCrypt |
| Dữ liệu | Spring Data JPA, PostgreSQL, Flyway |
| Media demo | Python 3.10+, FFmpeg, FFprobe |

## Cấu trúc

```text
backend/            API, bảo mật, truy cập dữ liệu và migration
mobile-frontend/    Ứng dụng Flutter Android
docs/               Tài liệu kiến trúc, API và yêu cầu nghiệp vụ
.github/workflows/  Workflow build backend và APK
```

Backend chia package theo chức năng. Flutter đi theo luồng View → ViewModel → Repository → ApiClient, dùng ChangeNotifier và dependency qua constructor.

## Chạy local

Chuẩn bị PostgreSQL và khóa JWT theo [hướng dẫn backend](backend/README.md), sau đó chạy từ `backend/`:

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local,demo"
```

Backend mặc định ở `http://localhost:8080`. Từ `mobile-frontend/`:

```powershell
flutter pub get
flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` trỏ từ Android Emulator về máy host. Với điện thoại qua USB, dùng `adb reverse` theo [hướng dẫn Flutter](mobile-frontend/README.md). Khi truy cập qua mạng, dùng HTTPS.

## Dữ liệu demo

Profile `demo` bổ sung ba tài khoản, ba video, ba bài nhạc, hai podcast, hai bài viết và dữ liệu Đã lưu/playlist. Seed thể loại, mẫu Quest và Badge đi cùng migration thông thường.

File media được tạo bằng `backend/scripts/prepare_demo_media.py` và không đưa vào Git. Thông tin tài khoản demo nằm trong README backend.

## Cấu hình

- Giữ mật khẩu, khóa JWT và cấu hình local ngoài Git; dùng các file `.example` làm mẫu.
- Flutter nhận `APP_ENV` và `API_BASE_URL` qua `--dart-define`.
- Bản Android debug hỗ trợ HTTP local; môi trường demo yêu cầu HTTPS.
- Flyway quản lý schema, Hibernate dùng `ddl-auto: validate`.

Xem [kiến trúc](docs/architecture.md), [hợp đồng API xác thực](docs/api/auth-contract.md), [API danh mục](docs/api/catalog-contract.md), [API phát & stream media](docs/api/playback-stream-contract.md), [API lượt phát & báo cáo tiến độ](docs/api/playback-progress-contract.md), [API phiên nghe nhạc/podcast](docs/api/listening-session-contract.md), [API Đã lưu](docs/api/saved-contract.md) và [API Playlist](docs/api/playlist-contract.md).



