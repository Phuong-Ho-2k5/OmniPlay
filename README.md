# OmniPlay

OmniPlay là ứng dụng Android kết hợp xem video, nghe nhạc, podcast và đọc bài viết, xây dựng bằng **Flutter** và **Spring Boot**. Nội dung mẫu được nhóm chuẩn bị, metadata lưu trong PostgreSQL và file media lưu riêng trên máy chủ.

## Trạng thái hiện tại

Repository đã có phần nền tảng để chạy Backend và ứng dụng Android, gồm:

- Schema PostgreSQL với 23 bảng, migration Flyway và dữ liệu demo.
- Cấu hình môi trường local/demo, User Repository và xử lý lỗi API thống nhất.
- Spring Security bảo vệ các đường dẫn nghiệp vụ; health endpoint truy cập công khai.
- Flutter theo MVVM, API Client dùng chung và màn kiểm tra kết nối đến Backend.
- Workflow GitHub Actions cho Backend và Android.

API đăng ký, đăng nhập, JWT, danh mục và các chức năng media chưa được triển khai. Màn hình hiện tại dùng để kiểm tra kết nối, chưa phải giao diện sử dụng đầy đủ của ứng dụng.

## Công nghệ

| Thành phần | Công nghệ |
| --- | --- |
| Ứng dụng | Flutter 3.47.9, Dart 3.13.7, Android |
| Backend | Java 21, Spring Boot 4.1.1, Maven Wrapper |
| API và bảo mật | Spring MVC, Spring Security, Bean Validation |
| Truy cập dữ liệu | Spring Data JPA, PostgreSQL |
| Migration | Flyway; Hibernate dùng `ddl-auto: validate` |
| Media mẫu | File local; Python, FFmpeg và FFprobe để tạo dữ liệu |

## Cấu trúc repository

```text
backend/          Backend Spring Boot, migration, seed và công cụ tạo media
mobile-frontend/  Ứng dụng Flutter Android
.github/workflows/  Workflow build Backend và Android
```

Backend tổ chức theo chức năng; các thành phần dùng chung nằm trong `common` và `config`. Frontend đi theo luồng **View → ViewModel → Repository → API Client**, dùng ChangeNotifier và truyền dependency qua constructor.

## Chạy local

Cần JDK 21, PostgreSQL, Flutter SDK và Android SDK. Để chạy ứng dụng, chuẩn bị một thiết bị Android hoặc emulator. Python và FFmpeg chỉ cần khi tạo media demo.

### Backend

Tạo database và cấu hình theo [hướng dẫn Backend](backend/README.md), sau đó mở terminal tại `backend/`:

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local,demo"
```

Backend mặc định chạy tại `http://localhost:8080`. Kiểm tra trong terminal khác:

```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
```

Kết quả cần có `status: UP`. Các đường dẫn nghiệp vụ yêu cầu xác thực; khi chưa có phiên hợp lệ, Backend trả JSON 401.

### Android

Mở terminal tại `mobile-frontend/`:

```powershell
flutter pub get
flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` trỏ đến máy host từ Android Emulator. Với máy thật, thay bằng IP LAN của máy chạy Backend và kết nối cùng mạng. Nhấn **Kiểm tra** trong ứng dụng để gọi health; nếu thất bại, ứng dụng hiển thị thông báo và cho **Thử lại**.

Cấu hình môi trường, cách build APK và cấu trúc MVVM nằm trong [hướng dẫn Frontend](mobile-frontend/README.md).

## Dữ liệu demo

Profile `demo` bổ sung 3 tài khoản, 3 video, 3 bài nhạc, 2 podcast, 2 bài viết và dữ liệu Đã lưu/playlist mẫu. Seed thể loại, 10 mẫu Quest và 3 Badge được nạp cùng migration thông thường.

File media được tạo bằng `backend/scripts/prepare_demo_media.py` và không đưa vào Git. Tài khoản seed hiện phục vụ chuẩn bị dữ liệu; chưa đăng nhập được qua API.

## Phạm vi chức năng dự kiến

| Nhóm | Chức năng |
| --- | --- |
| Tài khoản | Đăng ký, đăng nhập, gia hạn phiên, đăng xuất và hồ sơ |
| Khám phá | Danh mục video, nhạc, podcast, bài viết và tìm kiếm |
| Phát nội dung | Phát/tạm dừng, tua, tiếp tục và quản lý phiên nghe |
| Thư viện | Lưu nội dung, đọc bài viết và playlist nhạc |
| Dọn playlist | Ghi nhận Skip và gợi ý xử lý bài thường bị bỏ qua |
| Quest và phần thưởng | Nhiệm vụ trong ngày, XP, Level và Badge |
| Mystery Box | Chọn nội dung ngẫu nhiên theo bộ lọc |

## Cấu hình và bảo mật

- Dùng file `.example` làm mẫu; giữ mật khẩu database và cấu hình local ngoài Git.
- Frontend nhận `APP_ENV` và `API_BASE_URL` qua `--dart-define`; không dùng chúng để lưu secret.
- Dev hỗ trợ HTTP local trong bản Android debug. Môi trường demo yêu cầu URL HTTPS; cấu hình server HTTPS cần được chuẩn bị riêng.
- Flyway quản lý schema. Khi cần thay đổi schema đã áp dụng, thêm migration mới.



