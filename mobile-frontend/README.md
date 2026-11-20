# OmniPlay Android

Ứng dụng Flutter theo MVVM. Màn kiểm tra kết nối gọi Backend thật qua
View → ViewModel → HealthRepository → ApiClient. Mã nguồn được chia theo chức năng;
ViewModel dùng ChangeNotifier, các dependency được truyền qua constructor.

## Môi trường

- Flutter 3.47.9, Dart 3.13.7.
- JDK 21, Android SDK Platform 36, Android build tools và thiết bị/emulator.
- Backend đang chạy và PostgreSQL kết nối được.

Chạy lệnh từ `mobile-frontend/`. Nếu Flutter chưa có trên PATH, thêm thư mục `bin`
của SDK vào PATH hoặc gọi trực tiếp executable Flutter của máy.
Với Android SDK đặt riêng, thiết lập `ANDROID_HOME` hoặc cấu hình đường dẫn SDK local;
không đưa đường dẫn máy cá nhân trong `local.properties` vào Git.

## Chạy ứng dụng

```powershell
flutter pub get
flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` là địa chỉ máy host từ Android Emulator. Trên máy thật, thay bằng IP LAN
của máy chạy Backend, kết nối cùng mạng và cho phép cổng Backend qua firewall nếu cần.
`localhost` trên điện thoại trỏ đến chính điện thoại.

```powershell
flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://192.168.1.8:8080
flutter run --dart-define=APP_ENV=demo --dart-define=API_BASE_URL=https://demo.example.com
```

Dev mặc định dùng emulator nếu bỏ API_BASE_URL. Demo bắt buộc URL HTTPS rõ ràng.
URL chỉ gồm scheme, host và port tùy chọn; không thêm `/api`, query, fragment hoặc
thông tin đăng nhập. Không dùng dart-define để lưu secret. HTTP chỉ được bật trong
Android debug manifest; release dùng HTTPS và không cho cleartext.

Nhấn **Kiểm tra** để gọi `GET /actuator/health`. Thành công yêu cầu HTTP 200 và
`status: UP`. Khi thất bại, nhấn **Thử lại**. Lỗi mất mạng/TLS, timeout, HTTP và
response sai được phân biệt; timeout hủy request trước khi cho thử lại.

## Kiểm tra mã nguồn và build

```powershell
dart format --output=none --set-exit-if-changed lib
flutter analyze
flutter build apk --debug --dart-define=APP_ENV=dev
```

APK nằm tại `build/app/outputs/flutter-apk/app-debug.apk`. Đây là bản debug phục vụ
phát triển; chưa có cấu hình ký phát hành. Để kiểm tra kết nối thực tế, chạy Backend,
mở app trên Android và nhấn **Kiểm tra**. Dừng Backend rồi thử lại để kiểm tra trạng
thái lỗi; khởi động Backend và nhấn **Thử lại** để xác nhận kết nối được khôi phục.

## Cấu trúc

```text
lib/app/                       Khởi tạo và quản lý vòng đời dependency
lib/core/config/               Cấu hình dev/demo
lib/core/network/              HTTP, timeout, hủy request và lỗi chung
lib/features/connection/data/  HealthRepository
lib/features/connection/presentation/  State, ViewModel và màn hình
```

Màn kiểm tra hiện là công cụ phát triển. Đăng nhập, token và các chức năng nội dung
chưa được triển khai. Workflow Android được cấu hình trong
`.github/workflows/mobile-ci.yml` ở thư mục gốc repository.
