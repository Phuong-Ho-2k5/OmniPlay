# OmniPlay

OmniPlay là ứng dụng Android xây dựng bằng Flutter và Spring Boot, hướng tới xem video, nghe nhạc, podcast và đọc bài viết. Metadata lưu trong PostgreSQL; file media nằm trên máy chủ.

## Chức năng hiện có

- Đăng ký tài khoản với validation, chuẩn hóa email và mật khẩu BCrypt.
- Đăng nhập, cấp JWT và refresh token, lưu AuthSession trong PostgreSQL.
- Xác thực Bearer token, chuẩn hóa lỗi API và cung cấp health endpoint.
- Biểu mẫu Flutter theo MVVM, hiển thị lỗi theo trường và giữ token trong RAM.
- Schema PostgreSQL, migration Flyway, danh mục tham chiếu và dữ liệu demo.

Sau đăng nhập, ứng dụng mở màn kết nối dịch vụ. Các API nội dung, refresh/logout và lưu phiên lâu dài chưa được triển khai.

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

Xem [kiến trúc](docs/architecture.md) và [hợp đồng API xác thực](docs/api/auth-contract.md).



