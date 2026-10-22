# OmniPlay Backend

Backend cho ứng dụng di động OmniPlay, sử dụng Java 21, Spring Boot 4.1.1,
Spring MVC, Spring Security, Spring Data JPA, PostgreSQL và Flyway.

Hiện tại đây là bộ khung khởi tạo, chưa có API nghiệp vụ hoặc bảng dữ liệu.

## Yêu cầu

- JDK 21, đặt `JAVA_HOME` trỏ đến JDK.
- PostgreSQL cài trực tiếp trên máy.
- Maven Wrapper đã đi kèm, không cần cài Maven riêng.

Các lệnh bên dưới chạy từ thư mục `backend`.

## Chạy local (PowerShell)

Tạo database `omniplay` và user có quyền truy cập trong PostgreSQL trước khi chạy.

```powershell
Copy-Item src/main/resources/application-local.example.yaml src/main/resources/application-local.yaml
Copy-Item .env.example .env
# Sửa thông tin kết nối PostgreSQL trong .env trước khi chạy.
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
```

Trên macOS/Linux, dùng `cp` thay cho `Copy-Item` và chạy
`sh ./mvnw spring-boot:run -Dspring-boot.run.profiles=local`.

`application.yaml` chứa cấu hình chung: tên ứng dụng, JPA, Flyway và cổng server.
`application-local.yaml` chứa cấu hình kết nối PostgreSQL và đọc `.env`, chỉ được
nạp khi bật profile `local`. File local đã được Git bỏ qua; file
`application-local.example.yaml` là mẫu dùng chung để người clone repo tạo lại.
Trong IDE, đặt active profile là `local` hoặc biến môi trường `SPRING_PROFILES_ACTIVE=local`.

Ứng dụng đọc `.env` trong thư mục làm việc dưới dạng Java properties: mỗi dòng
`KEY=value`, không đặt giá trị trong dấu nháy. Biến môi trường hệ thống được ưu tiên
hơn `.env`. File này chỉ dành cho cấu hình local và đã được Git bỏ qua.

Backend mặc định chạy tại `http://localhost:8080`. File mẫu cấu hình PostgreSQL
ở `localhost:5432`.

Đặt `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_PORT` trong `.env`
khớp với database và user đã tạo trên máy.
`DATABASE_URL` có thể ghi đè URL kết nối và phải có dạng `jdbc:postgresql://host:port/database`.
Thay đổi `SERVER_PORT` nếu cổng 8080 đang được sử dụng.

Kiểm tra ứng dụng và kết nối database:

```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
```

Khi ứng dụng và database hoạt động, health trả về `{"status":"UP"}`.
Spring Security giữ cấu hình mặc định: health được truy cập công khai, các đường
dẫn còn lại yêu cầu đăng nhập. Tài khoản phát triển có username `user` và mật khẩu
tạm được in trong log mỗi lần khởi động. Cần thiết kế xác thực trước khi triển khai thực tế.

## Build và test

```powershell
.\mvnw.cmd -B clean verify
java -Duser.timezone=UTC -jar target/omniplay-backend-0.0.1-SNAPSHOT.jar --spring.profiles.active=local
```

Lệnh chạy JAR cần cấu hình PostgreSQL như hướng dẫn local ở trên.
Khi chạy ngoài môi trường local, cung cấp cấu hình datasource qua biến môi trường
chuẩn `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`.
Maven đã cấu hình JVM dùng UTC khi chạy ứng dụng. Khi chạy JAR trực tiếp, giữ
`-Duser.timezone=UTC` để tránh lỗi PostgreSQL không nhận alias múi giờ của hệ điều
hành, chẳng hạn `Asia/Saigon`.
Test khởi động Spring context dùng H2 trong bộ nhớ với profile `test`, không cần
PostgreSQL chạy riêng. Đây là smoke test cho cấu hình ứng dụng; chưa kiểm chứng tính
tương thích SQL với PostgreSQL. Khi có schema/API, cần bổ sung integration test
với PostgreSQL. H2 chỉ nằm trong test classpath, không được đóng gói vào ứng dụng.

GitHub Actions chạy cùng lệnh `clean verify` với Java 21.
Workflow nằm trong `.github/workflows/` ở gốc repository và chạy Maven trong `backend/`.

## Cấu trúc

```text
src/main/java/com/omniplay/       Điểm khởi động và mã nguồn ứng dụng
src/main/resources/              Cấu hình Spring Boot
src/main/resources/db/migration/ SQL migrations của Flyway
src/test/                       Test và cấu hình test
```

Flyway quản lý schema; Hibernate chỉ validate, không tự tạo bảng. Thêm migration
đầu tiên khi có thiết kế dữ liệu, ví dụ `V1__create_initial_tables.sql`.

## Chuẩn bị init commit

Các file `.env`, cấu hình local, `target/` và file IDE được loại khỏi Git.
Không commit mật khẩu thật, token hoặc private key. `.env.example` chỉ chứa giá trị mẫu.

Backend và mobile frontend được quản lý chung trong repository tại thư mục `omniplay`.
Xem [README tổng](../README.md#init-commit) để tạo init commit từ thư mục gốc.
