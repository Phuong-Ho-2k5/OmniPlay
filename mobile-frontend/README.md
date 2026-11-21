# OmniPlay Android

Ứng dụng Flutter theo MVVM với đăng ký, đăng nhập và màn kết nối dịch vụ. Luồng dữ liệu: View → ViewModel → Repository → ApiClient. ViewModel dùng ChangeNotifier, dependency được truyền qua constructor.

## Môi trường

- Flutter 3.50.1, Dart 3.14.0.
- JDK 21, Android SDK phù hợp Flutter và một thiết bị Android hoặc emulator.
- Backend đã cấu hình datasource và khóa JWT.

Chạy lệnh từ thư mục `mobile-frontend/`. Nếu SDK nằm ngoài PATH, thêm thư mục `bin` của Flutter vào PATH. Cấu hình đường dẫn Android SDK trên máy, không đưa `local.properties` vào Git.

## Chạy trên emulator

```powershell
flutter pub get
flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` trỏ tới máy host từ Android Emulator. `localhost` trên điện thoại/emulator là chính thiết bị đó.

## Chạy trên điện thoại qua USB

Lấy device ID bằng `adb devices`, sau đó thay `<deviceId>` bằng ID tương ứng:

```powershell
adb -s <deviceId> reverse tcp:8080 tcp:8080
flutter run -d <deviceId> --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Kết thúc kết nối USB bằng `adb -s <deviceId> reverse --remove tcp:8080`.

## Cấu hình môi trường

| Biến | Ý nghĩa |
| --- | --- |
| APP_ENV | `dev` hoặc `demo` |
| API_BASE_URL | Origin của backend, gồm scheme, host và port |

Dev mặc định dùng `http://10.0.2.2:8080` khi bỏ API_BASE_URL. Môi trường demo yêu cầu HTTPS:

```powershell
flutter run --dart-define=APP_ENV=demo --dart-define=API_BASE_URL=https://demo.example.com
```

URL không chứa `/api`, query, fragment hoặc thông tin đăng nhập. Không dùng dart-define để lưu secret. Android debug hỗ trợ HTTP local; release yêu cầu HTTPS.

## Luồng tài khoản

App mở ở màn Đăng nhập. Tạo tài khoản thành công sẽ quay lại Login, điền email chuẩn hóa và xóa password. Đăng nhập thành công mở màn kết nối dịch vụ.

Biểu mẫu kiểm tra độ dài Unicode/UTF-8 và xác nhận mật khẩu; backend quyết định định dạng email. Lỗi 400 hiện theo trường; email trùng và sai mật khẩu có thông báo riêng. Nút gửi và điều hướng biểu mẫu bị khóa khi request đang chờ.

Password giữ nguyên và chỉ nằm trong controller của biểu mẫu. Token được giữ cả cặp trong RAM; mở lại app cần đăng nhập lại. Chưa hỗ trợ tự refresh, logout hoặc lưu token lâu dài.

ApiClient gửi JSON UTF-8, gắn Bearer cho request cần xác thực và không gắn token vào auth/health. Timeout hủy request; POST không tự gửi lại. Đăng ký mất phản hồi sẽ hiển thị trạng thái chưa xác nhận và cho phép quay về Login.

Màn kết nối gọi `GET /actuator/health`; nút Thử lại cho phép gửi lại khi lỗi mạng hoặc dịch vụ.

## Build APK

```powershell
dart format lib
flutter analyze
flutter build apk --debug --dart-define=APP_ENV=dev
```

APK nằm tại `build/app/outputs/flutter-apk/app-debug.apk`. Có thể truyền API_BASE_URL vào lệnh build để chọn backend. Bản debug phục vụ phát triển; chưa có cấu hình ký phát hành.

## Cấu trúc mã nguồn

```text
lib/app/                       Khởi tạo ứng dụng và dependency
lib/core/config/               Môi trường và URL backend
lib/core/network/              HTTP, timeout và lỗi API
lib/features/auth/data/        AuthRepository và session store
lib/features/auth/models/      RegisteredUser và TokenPair
lib/features/auth/presentation/ State, validator, ViewModel, biểu mẫu và AuthGate
lib/features/connection/       Repository, ViewModel và màn kết nối
```

AppDependencies sở hữu một HTTP client, ApiClient và session store dùng chung. ViewModel của từng màn được tạo một lần và dispose cùng controller khi rời màn.
