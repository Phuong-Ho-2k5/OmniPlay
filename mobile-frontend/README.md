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

App đọc phiên trong vùng lưu trữ bảo mật trước khi chọn màn hình. Phiên còn hạn
refresh được khôi phục vào màn kết nối; phiên thiếu/hỏng/hết hạn trở về Login.
Tạo tài khoản thành công quay lại Login, điền email chuẩn hóa và xóa password.
Đăng nhập chỉ được xác nhận sau khi thao tác lưu cả cặp token hoàn tất.

Biểu mẫu kiểm tra độ dài Unicode/UTF-8 và xác nhận mật khẩu; backend quyết định định dạng email. Lỗi 400 hiện theo trường; email trùng và sai mật khẩu có thông báo riêng. Nút gửi và điều hướng biểu mẫu bị khóa khi request đang chờ.

Password giữ nguyên và chỉ nằm trong controller của biểu mẫu. TokenPair được
lưu thành một JSON dưới một key của flutter_secure_storage; không lưu password.
Các thao tác storage được tuần tự hóa. Mã phiên và phiên bản token ngăn response
đến muộn ghi đè login mới hoặc phục hồi phiên đã đăng xuất. Android backup được
tắt để tránh khôi phục ciphertext mà thiếu khóa thiết bị.

ApiTransport gửi JSON UTF-8 và hủy request khi timeout. AuthRepository gọi
transport trực tiếp cho register/login/refresh/logout; không gắn access token
hoặc tự gửi lại các POST auth. Đăng ký mất phản hồi hiển thị trạng thái chưa
xác nhận và cho phép quay về Login.

ApiClient gắn Bearer cho request nghiệp vụ. Khi nhận ACCESS_TOKEN_EXPIRED, các
request chia sẻ một lượt refresh; lưu cả cặp mới rồi thử lại request gốc tối đa
một lần. Body JSON giữ snapshot ban đầu. Response cũ sau khi đổi tài khoản bị
bỏ qua. Refresh bị từ chối thì xóa phiên và về Login; network/timeout/5xx giữ
phiên và trả lỗi kết nối để người dùng thử lại.

Nút Đăng xuất gọi API thu hồi bằng snapshot refresh token và xóa token local
kể cả khi mất mạng. Khi chưa xác nhận server, Login hiển thị thông báo kết nối.
Lỗi đọc/ghi/xóa storage có màn lỗi và Thử lại; retry xóa không đọc lại token cũ.
Storage-only retry giữ nhận diện logout đang chờ để kết quả server vẫn được
ghi nhận, nhưng không ảnh hưởng phiên login mới.

Ứng dụng chờ Future của plugin, không cam kết dữ liệu đã được ép flush xuống
đĩa. flutter_secure_storage 11.2.0 trên Android dùng SharedPreferences.apply()
cho write/delete; lỗi disk và tình huống process bị kill ngay sau thao tác
cần kiểm chứng trên thiết bị.

Màn kết nối gọi `GET /actuator/health`; nút Thử lại cho phép gửi lại khi lỗi mạng hoặc dịch vụ.
Health là API công khai nên không minh chứng refresh của request được bảo vệ;
luồng đó cần kiểm tra với catalog thật khi API/màn nội dung được triển khai.
Player/progress chưa có để nối dừng phát/lưu tiến độ vào logout.

## Kiểm tra mã nguồn

```powershell
flutter analyze
dart format --output=none --set-exit-if-changed lib
```

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

AppDependencies sở hữu HTTP client, raw transport, AuthRepository, session
controller, refresh coordinator và ApiClient dùng chung. AuthRepository được
tạo trước session controller và truyền callback logout để tránh vòng phụ thuộc.
ViewModel của từng màn được tạo một lần và dispose khi rời màn.
