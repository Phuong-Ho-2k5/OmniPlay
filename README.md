# OmniPlay

Ứng dụng Android tích hợp **xem video, nghe nhạc, podcast và đọc bài viết**, xây dựng bằng **Flutter** và **Spring Boot**.

OmniPlay cho phép người dùng khám phá nội dung, tìm kiếm theo chủ đề, quản lý thư viện cá nhân và tự đăng video, nhạc, podcast hoặc bài viết. Phần Read hỗ trợ cả bài tự viết và bài từ nguồn bên ngoài có ghi nguồn, liên kết gốc.

## Trạng thái dự án

Dự án đang ở giai đoạn khởi tạo và thiết lập backend. Phạm vi chức năng, tài liệu thiết kế, mockup và kế hoạch phát triển đã được chuẩn bị. Các chức năng bên dưới là mục tiêu triển khai, chưa thể hiện trạng thái hoàn thành trong mã nguồn.

## Chức năng dự kiến

| Nhóm | Chức năng |
| --- | --- |
| Tài khoản | Đăng ký, đăng nhập, đăng xuất, cập nhật hồ sơ và sở thích |
| Home | Nội dung nổi bật, mới, phổ biến, gợi ý cơ bản và tiếp tục sử dụng |
| Watch | Danh sách video, phát/tạm dừng, tua, toàn màn hình và lưu xem sau |
| Listen | Nhạc, podcast, mini player, hàng đợi, shuffle, repeat và nghe nền Android |
| Read | Đọc bài, lưu đọc sau, hiển thị tác giả/nguồn và mở bài gốc |
| Search | Tìm kiếm video, nhạc, podcast và bài viết, có bộ lọc theo loại |
| Library | Yêu thích, xem sau, đọc sau, playlist và lịch sử |
| Playlist | Tạo, đổi tên, xóa, thêm/xóa và sắp xếp nhạc hoặc podcast |
| Đăng nội dung | Upload media, nhập metadata, xem tiến độ xử lý và xuất bản |
| Bài viết | Soạn bài, lưu nháp, xem trước, xuất bản hoặc chia sẻ bài từ URL |
| Quản lý cá nhân | Xem, sửa, ẩn và xóa nội dung do mình đăng |
| Quản trị | Tiếp nhận báo cáo, xử lý báo cáo và ẩn nội dung |

Phiên bản đầu tập trung Android. iOS, livestream, thanh toán, tải media offline và gợi ý bằng học máy thuộc hướng phát triển sau.

## Công nghệ

| Thành phần | Công nghệ |
| --- | --- |
| Mobile | Flutter, Dart, Android |
| Backend | Java 21, Spring Boot 4.1.1, Maven |
| REST API | Spring Web |
| Bảo mật | Spring Security; dự kiến sử dụng access token và refresh token |
| Truy cập dữ liệu | Spring Data JPA |
| Database | PostgreSQL theo thiết kế đề xuất |
| Database migration | Flyway |
| Kiểm tra dữ liệu | Bean Validation |
| Media storage | Đang lựa chọn giải pháp lưu file |
| Xử lý media | Worker nền; công cụ và cách triển khai đang được lựa chọn |

Spring Security là nền tảng bảo mật. API đăng nhập, cấp token và kiểm tra quyền sở hữu tài nguyên sẽ được triển khai trong backend.

## Kiến trúc dự kiến

Flutter gọi REST API của Spring Boot để làm việc với tài khoản, metadata nội dung, thư viện và lịch sử. PostgreSQL lưu dữ liệu nghiệp vụ; video, audio và ảnh được lưu riêng trong kho media.

Luồng đăng media gồm: tạo nháp, tải file, xử lý nền, kiểm tra kết quả và xuất bản. Chỉ nội dung đã công khai, có file phát sẵn sàng mới xuất hiện trên Home và Search. Worker phụ trách kiểm tra file, lấy thời lượng, tạo thumbnail và chuẩn bị file phát.

Backend tổ chức theo monolith chia module: `auth`, `user`, `content`, `upload`, `search`, `library`, `history`, `provider`, `recommendation` và `moderation`.



