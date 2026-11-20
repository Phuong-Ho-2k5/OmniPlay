# OmniPlay Backend

Backend cho ứng dụng OmniPlay, sử dụng Java 21, Spring Boot 4.1.1, Spring MVC,
Spring Security, Spring Data JPA, PostgreSQL và Flyway.

Hiện đã có schema database, seed thể loại, Quest, Badge và dữ liệu demo kèm media
local. API nghiệp vụ đăng nhập, danh mục, streaming và Quest chưa được triển khai.

## Yêu cầu

- JDK 21 và `JAVA_HOME` trỏ đến JDK.
- PostgreSQL đang chạy. Các ví dụ Windows bên dưới dùng PostgreSQL 18.
- Maven Wrapper đi kèm dự án.
- Python 3.10+, FFmpeg và FFprobe nếu cần tạo media demo.

Chạy các lệnh bên dưới từ thư mục `backend/`.

## Chạy local trên Windows

### 1. Tạo user và database

Mở PostgreSQL bằng tài khoản quản trị:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -h localhost
```

Nhập mật khẩu `postgres`, rồi chạy SQL bên dưới. Thay mật khẩu mẫu bằng mật khẩu
bạn chọn; bỏ qua lệnh tạo user nếu user đó đã tồn tại.

```sql
CREATE USER omniplay_dev WITH PASSWORD 'your_database_password';
CREATE DATABASE omniplay_local OWNER omniplay_dev;
\q
```

Database cần trống ở lần chạy đầu. Nếu đã dùng bản migration gộp V1/V2/V3 cũ,
hãy tạo database development/demo mới cho cấu trúc migration hiện tại.

### 2. Cấu hình kết nối

Tạo các file local nếu chưa có:

```powershell
if (!(Test-Path .env)) {
    Copy-Item .env.example .env
}
if (!(Test-Path src/main/resources/application-local.yaml)) {
    Copy-Item src/main/resources/application-local.example.yaml src/main/resources/application-local.yaml
}
notepad .env
```

Điền thông tin khớp với database và user đã tạo:

```dotenv
POSTGRES_DB=omniplay_local
POSTGRES_USER=omniplay_dev
POSTGRES_PASSWORD=your_database_password
POSTGRES_PORT=5432
SERVER_PORT=8080
```

`.env` được đọc dưới dạng Java properties, mỗi dòng `KEY=value`, không đặt giá trị
trong dấu nháy. Biến môi trường hệ thống được ưu tiên hơn `.env`. Có thể đặt
`DATABASE_URL=jdbc:postgresql://host:port/database` để ghi đè URL kết nối.

Profile `local` nạp `application-local.yaml` và `.env` từ thư mục làm việc.
Các file local này đã được Git bỏ qua; file `.example` là cấu hình mẫu dùng chung.

### 3. Tạo media mẫu khi dùng demo

FFmpeg và FFprobe cần có trên PATH, hoặc nằm trong `.tools/ffmpeg/bin/`.
Cũng có thể chỉ định đường dẫn executable bằng hai biến `FFMPEG` và `FFPROBE`.

```powershell
python scripts/prepare_demo_media.py
```

Script tạo 3 video MP4 H.264/AAC, 3 bài nhạc MP3, 2 podcast MP3 và 8 thumbnail JPEG
trong `media/demo/`, theo `demo/media-manifest.json`. Đây là nội dung tổng hợp phục vụ
demo; podcast dùng âm thanh giả lập. UUID, đường dẫn và thời lượng khớp seed database.

Chạy lại sẽ giữ file hiện có và kiểm tra chúng. Dùng `--force` để tạo lại file mẫu.
Mặc định media root là `./media`; nếu đổi vị trí, đặt `MEDIA_ROOT` và truyền cùng
đường dẫn cho generator qua `--media-root`. Các đường dẫn trong database tương đối
với media root. `media/` và `.tools/` được Git bỏ qua.

### 4. Khởi động backend

Chạy cùng dữ liệu demo:

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local,demo"
```

Nếu chỉ cần schema và seed thể loại, Quest, Badge:

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
```

Flyway tự áp dụng migration khi backend khởi động. Chạy lại trên cùng database
không nạp trùng seed. Khi database đã nạp demo, tiếp tục dùng `local,demo`;
tắt profile `demo` không xóa dữ liệu đã nạp.

Trong IDE, đặt working directory là `backend/` và active profiles là `local,demo`
hoặc `local`. Backend mặc định chạy tại `http://localhost:8080`.

### 5. Kiểm tra kết nối

Mở cửa sổ PowerShell khác:

```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
```

Kết quả mong đợi là `{"status":"UP"}`. Spring Security hiện dùng cấu hình mặc định:
health truy cập công khai, các đường dẫn khác yêu cầu xác thực. Tài khoản mặc định
`user` và mật khẩu in trong log khởi động tách biệt với các tài khoản seed trong database.

## Migration và seed

| Phiên bản | Nội dung |
| --- | --- |
| V1 | Tạo 4 enum PostgreSQL |
| V2–V24 | Tạo 23 bảng, mỗi bảng một file; tổng cộng 130 cột |
| V25 | Tạo toàn bộ 34 FK |
| V26 | Tạo 25 index bổ sung; index PK/UNIQUE được tạo cùng ràng buộc bảng |
| V27 | Nạp 4 thể loại, Q01–Q10 và 3 Badge |
| V28, chỉ bật với profile `demo` | Nạp tài khoản, 8 media, 2 Post, dữ liệu Đã lưu và playlist mẫu |

Flyway quản lý schema; Hibernate dùng `ddl-auto: validate`. Khi thay đổi schema đã
được áp dụng, thêm migration mới. Không sửa checksum hoặc bật baseline để ép dùng
một database có lịch sử migration khác.

Thiết kế gốc nằm trong [tài liệu database](../docs/Database/). Quy tắc XP dưới đây
thay thế mức cố định 10 XP trong tài liệu gốc.

## Dữ liệu demo

Mật khẩu của cả ba tài khoản là `OmniPlayDemo!2026`, được lưu bằng BCrypt cost 10.
Các tài khoản này sẵn sàng cho API xác thực ở giai đoạn tiếp theo.

| Email | Dữ liệu ban đầu |
| --- | --- |
| `normal@demo.omniplay.local` | Chưa lưu nội dung, XP 0, Level 1 |
| `saved@demo.omniplay.local` | Lưu 8 media và 1 Post |
| `cleanup@demo.omniplay.local` | Playlist 3 bài nhạc; bài đầu có 5 Skip và còn bài kế |

Không cấp sẵn Daily Quest, Badge cho người dùng, phiên đăng nhập hoặc tiến độ phát.

Thưởng Quest bằng số nội dung mục tiêu nhân **10 XP cho ANY** hoặc **15 XP cho SAVED**:

| Quest | Mục tiêu | Tổng XP |
| --- | --- | --- |
| Q01, Q02, Q07 | 1 nội dung ANY | 10 |
| Q03, Q04, Q06 | 1 nội dung SAVED | 15 |
| Q05 | 2 nội dung SAVED | 30 |
| Q08, Q09 | 2 nội dung ANY | 20 |
| Q10 | 3 nội dung ANY | 30 |

Database kiểm tra công thức ở cả mẫu Quest và bản chụp Daily Quest. Thưởng được nhận
một lần khi hoàn thành cả Quest. Badge mở tại 10/50/100 XP; Level bằng `1 + total_xp / 100`
với phép chia nguyên.

## Build và chạy JAR

```powershell
.\mvnw.cmd -B clean package -Dmaven.test.skip=true
java -Duser.timezone=UTC -jar target/omniplay-backend-0.0.1-SNAPSHOT.jar --spring.profiles.active=local,demo
```

Giữ `-Duser.timezone=UTC` khi chạy JAR để PostgreSQL không nhận alias múi giờ của hệ
điều hành. Maven đã cấu hình tùy chọn này khi dùng `spring-boot:run`.

Trên macOS/Linux, dùng `sh ./mvnw` thay cho `.\mvnw.cmd`, và `cp` thay cho `Copy-Item`.
Khi chạy ngoài profile `local`, cung cấp datasource qua `SPRING_DATASOURCE_URL`,
`SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`. GitHub Actions build bằng Java 21.

## Cấu trúc thư mục

```text
src/main/java/com/omniplay/       Mã nguồn backend
src/main/resources/              Cấu hình ứng dụng
src/main/resources/db/migration/ Enum, bảng, FK, index và seed danh mục
src/main/resources/db/demo/      Seed dữ liệu demo
demo/media-manifest.json         Metadata dùng để tạo media mẫu
scripts/prepare_demo_media.py    Công cụ tạo media mẫu
media/                          Media local, được Git bỏ qua
```
