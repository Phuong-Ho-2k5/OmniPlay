# OmniPlay Backend

Backend Java 21 / Spring Boot 4.1.1, sử dụng Spring MVC, Spring Security, Spring Data JPA, PostgreSQL và Flyway.

Backend hỗ trợ đăng ký, đăng nhập, refresh rotation, đăng xuất, xác thực JWT, danh mục/tìm kiếm nội dung, phát & stream media có HTTP Range, theo dõi tiến độ/segment 90%, hai phiên nghe Nhạc/Podcast độc lập, Đã lưu, playlist cá nhân, ghi nhận Skip hợp lệ, dọn playlist, Daily Quest (cấp bộ, cập nhật tiến độ, nhận XP/Level/Badge) và Mystery Box. GET health cùng bốn POST auth truy cập công khai; các API nghiệp vụ còn lại yêu cầu Bearer token.

## Yêu cầu

- JDK 21 và `JAVA_HOME` trỏ đến JDK.
- PostgreSQL đang chạy; ví dụ dưới đây dùng PostgreSQL 18.
- Maven Wrapper đi kèm repository.
- Python 3.10+, FFmpeg và FFprobe khi tạo media demo.

Chạy các lệnh từ thư mục `backend/`.

## Cấu hình local

### Database

Mở PostgreSQL bằng tài khoản quản trị:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -h localhost
```

Tạo user và database bằng mật khẩu do bạn chọn:

```sql
CREATE USER omniplay_dev WITH PASSWORD 'your_database_password';
CREATE DATABASE omniplay_local OWNER omniplay_dev;
```

Lần khởi động đầu cần database trống để Flyway tạo schema.

### Datasource

Tạo file cấu hình từ mẫu nếu chưa có:

```powershell
if (-not [System.IO.File]::Exists('.env')) {
    Copy-Item .env.example .env
}
if (-not [System.IO.File]::Exists('src/main/resources/application-local.yaml')) {
    Copy-Item src/main/resources/application-local.example.yaml src/main/resources/application-local.yaml
}
```

Điền các giá trị trong `.env`:

```dotenv
POSTGRES_DB=omniplay_local
POSTGRES_USER=omniplay_dev
POSTGRES_PASSWORD=your_database_password
POSTGRES_PORT=5432
SERVER_PORT=8080
```

Profile `local` nạp `application-local.yaml` và `.env` từ working directory. Giá trị `.env` dùng cú pháp Java properties `KEY=value`, không đặt trong dấu nháy. Biến môi trường hệ thống được ưu tiên hơn file local.

Có thể đặt `DATABASE_URL=jdbc:postgresql://host:port/database` để ghi đè URL. Khi không dùng profile local, cung cấp `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`.

### Khóa JWT

`JWT_SECRET_BASE64` bắt buộc là Base64 của ít nhất 32 byte ngẫu nhiên. Backend dừng khởi động nếu khóa thiếu, sai định dạng hoặc quá ngắn.

Có thể tạo khóa trong terminal hiện tại:

```powershell
if (-not $env:JWT_SECRET_BASE64) {
    $jwtBytes = New-Object byte[] 32
    $jwtRng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $jwtRng.GetBytes($jwtBytes)
    $env:JWT_SECRET_BASE64 = [Convert]::ToBase64String($jwtBytes)
    $jwtRng.Dispose()
    Remove-Variable jwtBytes,jwtRng
}
```

Có thể cung cấp cùng biến qua file `.env`. Giữ cùng khóa khi khởi động lại để access token đã cấp tiếp tục hợp lệ. Không đưa khóa thật vào Git hoặc log.

## Khởi động

Chạy với dữ liệu demo:

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local,demo"
```

Chỉ nạp schema và danh mục tham chiếu:

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
```

Trong IDE, đặt working directory là `backend/`. Server mặc định chạy ở `http://localhost:8080`. GET `/actuator/health` là endpoint theo dõi trạng thái dịch vụ, bao gồm kết nối PostgreSQL, với chi tiết nội bộ được ẩn.

## API tài khoản

| Method | Endpoint | Chức năng |
| --- | --- | --- |
| POST | `/auth/register` | Tạo tài khoản |
| POST | `/auth/login` | Đăng nhập và cấp cặp token |
| POST | `/auth/refresh` | Đổi refresh token và cấp cặp token mới |
| POST | `/auth/logout` | Thu hồi phiên hiện tại, trả 204 không body |
| GET | `/actuator/health` | Trạng thái dịch vụ |

Register nhận `{email, password, displayName}`, trả HTTP 201 với `{userId, email, displayName}`. Email trim/lowercase; tên hiển thị trim. Password giữ nguyên, có ít nhất 8 Unicode code point và tối đa 72 byte UTF-8, lưu bằng BCrypt cost 10.

Login nhận `{email, password}`, trả HTTP 200 với `{accessToken, refreshToken, tokenType, accessExpiresIn, refreshExpiresAt}`. Access token có hiệu lực 900 giây. Mỗi login tạo AuthSession riêng, hết hạn sau 168 giờ; database chỉ lưu SHA-256 của toàn refresh token.

Refresh/logout nhận `{refreshToken}` trong JSON body, không yêu cầu access token.
Refresh giữ hạn tuyệt đối 168 giờ của phiên gốc; token cũ dùng lại thu hồi đúng
phiên. Logout xác minh hash hiện hành hoặc history, trả 204 không body kể cả khi
phiên hết hạn/đã thu hồi hoặc token lạ. Thiếu/null/sai kiểu trường trả 400.

Các API được bảo vệ nhận `Authorization: Bearer <accessToken>`. Backend xác minh HS256, issuer, audience, UUID user/phiên và thời hạn. Health và bốn API auth công khai bỏ qua header token cũ/sai. HTTP Basic, form login và HTTP session được tắt. Logout không vô hiệu JWT ngay; access token đã cấp giữ mốc hết hạn ban đầu.

Lỗi dùng cấu trúc `{code, message, fieldErrors}`:

| HTTP | Code |
| --- | --- |
| 400 | VALIDATION_ERROR |
| 401 | INVALID_CREDENTIALS, ACCESS_TOKEN_INVALID, ACCESS_TOKEN_EXPIRED, REFRESH_TOKEN_INVALID, REFRESH_TOKEN_EXPIRED |
| 403 | FORBIDDEN |
| 409 | EMAIL_ALREADY_USED |
| 500 | INTERNAL_ERROR |

Lõi refresh rotation nằm trong `RefreshRotationService`: khóa dòng
AuthSession, đổi hash token, ghi history và giữ hạn phiên gốc 168 giờ. Replay thu
hồi đúng phiên; sai secret không đổi trạng thái. Kết quả bị từ chối được trả về
dưới dạng `RefreshResult.Rejected` để transaction thu hồi commit trước khi tầng
gọi chuyển thành lỗi HTTP. Controller refresh/logout xử lý
validation JSON và bảo mật cho các POST công khai.

## API nghiệp vụ

| Method | Endpoint | Chức năng |
| --- | --- | --- |
| GET | `/catalog` | Danh mục VIDEO, MUSIC, PODCAST, POST; lọc type và phân trang |
| GET | `/catalog/search` | Tìm title bằng `q`, lọc `type`/`genreId` theo AND |
| GET | `/catalog/{id}?type=...` | Chi tiết metadata hoặc văn bản Post |
| GET | `/genres` | Danh sách thể loại |
| GET | `/media/{id}/thumbnail` | Ảnh JPEG/PNG/WebP có JWT |
| GET | `/media/{id}/playback` | Metadata phát, vị trí tiếp tục, độ phủ và đường dẫn stream |
| GET | `/media/{id}/stream` | Stream media có JWT hỗ trợ HTTP Range (`200`/`206`/`416`) |
| POST | `/me/playback-attempts` | Khởi tạo/xác minh lượt phát idempotent theo `attemptId` |
| PUT | `/me/progress/{mediaId}` | Báo cáo segment/tiến độ 90% và đánh giá tiến độ Daily Quest |
| POST | `/me/playback-skips` | Ghi nhận Skip hợp lệ trong hàng đợi playlist (khóa chống lặp) |
| GET / PUT | `/me/listening-sessions/{type}` | Đọc/lưu hai phiên nghe độc lập (`music` / `podcast`) và hàng đợi nhạc |
| GET / PUT | `/me/saved`, `/me/saved/{id}` | Danh sách Đã lưu theo `savedAt` giảm dần và lưu/bỏ lưu idempotent |
| GET / POST / PATCH / DELETE | `/me/playlists`, `/me/playlists/{id}` | CRUD playlist cá nhân (tạo idempotent theo `requestId`) |
| PUT / DELETE | `/me/playlists/{id}/items/{mediaId}` | Thêm/gỡ bài nhạc trong playlist (chỉ nhận MUSIC khả dụng) |
| GET / PATCH | `/me/cleanup-suggestions`, `/me/cleanup-suggestions/{playlistItemId}` | Gợi ý dọn playlist (`>= 6` skip) và xử lý `KEEP`/`DISMISS`/`REMOVE` |
| POST / GET | `/me/quests/today/ensure`, `/me/quests/today` | Cấp (khóa theo user, snapshot `SAVED`) và đọc bộ 4 Daily Quest theo ngày Việt Nam |
| GET | `/me/quests/{questId}/media` | Danh sách media phù hợp của từng Quest (phân trang) |
| POST | `/me/quests/{questId}/claim` | Nhận thưởng XP, cập nhật Level và mở khóa Badge idempotent |
| POST | `/mystery-box/draw` | Chọn ngẫu nhiên media theo bộ lọc AND (`FOUND`/`NO_ALTERNATIVE`/`EMPTY`) |

Danh sách phân trang trả `{items,page,size,totalElements}`, `page` từ 0, `size` mặc định 20 và tối đa 50. Nội dung hiển thị phải đang khả dụng (riêng `/me/saved` giữ lại mục ngừng phục vụ với `available: false` để người dùng bỏ lưu). Ảnh bìa và file media nằm dưới `MEDIA_ROOT` (mặc định `./media`), trả `Cache-Control: private, no-store`, chặn path traversal/symlink ra ngoài thư mục gốc và không công khai đường dẫn vật lý.

## Migration và seed

| Phiên bản | Nội dung |
| --- | --- |
| V1 | Bốn enum PostgreSQL |
| V2–V24 | 23 bảng, mỗi bảng một file |
| V25 | Foreign key |
| V26 | Index bổ sung |
| V27 | Thể loại, mẫu Quest và Badge |
| V28 với profile demo | Tài khoản, media, bài viết, Đã lưu và playlist mẫu |

Flyway quản lý schema; Hibernate dùng `ddl-auto: validate`. Thay đổi schema bằng migration mới, không sửa checksum của migration đã áp dụng. Tắt profile demo không xóa dữ liệu đã nạp.

## Dữ liệu demo

Ba tài khoản dùng mật khẩu `OmniPlayDemo!2026`, được lưu bằng BCrypt:

| Email | Dữ liệu ban đầu |
| --- | --- |
| `normal@demo.omniplay.local` | XP 0, Level 1, chưa lưu nội dung |
| `saved@demo.omniplay.local` | Lưu tám media và một bài viết |
| `cleanup@demo.omniplay.local` | Playlist ba bài nhạc, bài đầu có năm Skip |

Không cấp sẵn phiên đăng nhập, Daily Quest, Badge người dùng hoặc tiến độ phát.

Tạo media mẫu:

```powershell
python scripts/prepare_demo_media.py
```

FFmpeg/FFprobe cần trên PATH hoặc trong `.tools/ffmpeg/bin/`. Có thể chỉ định executable bằng `FFMPEG` và `FFPROBE`. Script tạo video MP4, âm thanh MP3 và thumbnail theo `demo/media-manifest.json`. Media root mặc định là `./media`; có thể đổi bằng `MEDIA_ROOT` và `--media-root`.

Thưởng Quest bằng `target_count × 10 XP` cho ANY hoặc `target_count × 15 XP` cho SAVED. Badge mở tại 10/50/100 XP; Level bằng `1 + total_xp / 100` với phép chia nguyên.

## Build và chạy JAR

```powershell
.\mvnw.cmd -B clean package
java "-Duser.timezone=UTC" -jar target/omniplay-backend-0.0.1-SNAPSHOT.jar --spring.profiles.active=local,demo
```

Maven đã cấu hình timezone UTC cho `spring-boot:run`. Trên macOS/Linux, dùng `sh ./mvnw` thay cho `.\mvnw.cmd`.

## Mã nguồn

```text
src/main/java/com/omniplay/auth/       Xác thực, phiên và token
src/main/java/com/omniplay/user/       Entity và repository tài khoản
src/main/java/com/omniplay/catalog/    Danh mục, tìm kiếm, chi tiết và ảnh bìa
src/main/java/com/omniplay/playback/   Metadata phát, stream HTTP Range, tiến độ 90%, Skip và hai phiên nghe
src/main/java/com/omniplay/saved/      Danh sách Đã lưu và lưu/bỏ lưu nội dung
src/main/java/com/omniplay/playlist/   Playlist cá nhân, bài nhạc trong playlist và gợi ý dọn playlist
src/main/java/com/omniplay/quest/      Cấp bộ Daily Quest, đánh giá tiến độ và nhận thưởng XP/Level/Badge
src/main/java/com/omniplay/mystery/    Mystery Box chọn ngẫu nhiên media theo bộ lọc
src/main/java/com/omniplay/dto/        Request/response
src/main/java/com/omniplay/config/     Bean và cấu hình bảo mật/JSON
src/main/java/com/omniplay/common/     Lỗi API dùng chung
src/main/resources/db/migration/      Schema và danh mục tham chiếu
src/main/resources/db/demo/           Dữ liệu demo
```
