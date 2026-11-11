# WashCare

Đồ án học phần CMP177 của Nhóm 7. WashCare là ứng dụng Flutter quản lý dịch vụ giặt ủi và giao nhận. Khách chọn dịch vụ, đặt lịch lấy đồ, theo dõi và đánh giá đơn. Ứng dụng hỗ trợ thanh toán tiền mặt khi nhận đồ (COD) và hiển thị mã VietQR để khách chuyển khoản. Quản trị viên quản lý đơn, dịch vụ và tài khoản.

[Kho mã nguồn](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7) · [Lịch sử commit](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7/commits/main/) · [Pull requests](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7/pulls?q=is%3Apr)

## Chạy trên Android

Cài Flutter SDK phù hợp với yêu cầu Dart trong `pubspec.yaml` và Android SDK. Kết nối điện thoại Android hoặc mở máy ảo, sau đó chạy:

```sh
git clone https://github.com/nguyenbaoky1177/WASHCARE_NHOM7.git
cd WASHCARE_NHOM7
flutter pub get
flutter run
```

Ứng dụng đọc URL và khóa công khai dành cho client (Supabase publishable key) từ [lib/supabase_config.dart](lib/supabase_config.dart). Nếu dùng dự án Supabase khác, thay hai giá trị này bằng cấu hình của dự án đó. Tài khoản quản trị cần được cấp vai trò trên máy chủ.

Giữ mật khẩu, token và khóa bí mật như Supabase `service_role` trong hệ thống quản lý bí mật của môi trường chạy. Chỉ đưa cấu hình công khai dành cho client vào repo.

## Cấu trúc thư mục

| Thư mục | Nội dung |
| --- | --- |
| `lib/pages/` | Màn hình khách hàng và quản trị viên. |
| `lib/widgets/` | Các thành phần giao diện như tóm tắt đơn, thanh đặt đơn và trạng thái. |
| `lib/core/` | Logic dùng chung, truy cập dữ liệu, cài đặt giao diện và bộ nhớ đệm. |
| `lib/models/` | Mô hình dữ liệu đơn hàng, dịch vụ, địa chỉ và tài khoản. |
| `test/` | Kiểm thử Dart và Flutter. |
| `supabase/` | Cấu hình, migration, Edge Functions và kiểm thử backend. |

## Build APK để nộp

```sh
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

APK nằm trong `build/app/outputs/flutter-apk/`. Dùng `app-arm64-v8a-release.apk` cho điện thoại Android ARM64, hoặc `app-x86_64-release.apk` cho máy ảo x86_64. Bản build của đồ án dùng cấu hình ký debug hiện có để cài thử.

## Trình diễn

- **Khách hàng** — chọn dịch vụ, lịch lấy đồ và địa chỉ, tạo đơn COD, tìm theo mã, theo dõi trạng thái và đánh giá khi đơn hoàn tất.
- **Quản trị viên** — tìm đơn, cập nhật lần lượt các trạng thái, rồi xác nhận thu tiền COD sau khi giao xong.
- **Giao diện** — đổi sáng/tối và Việt/Anh tại **Tài khoản → Giao diện & Ngôn ngữ**. Một số màn hình và nội dung dịch vụ từ máy chủ vẫn hiển thị tiếng Việt.

Dùng hai phiên đăng nhập riêng cho khách và quản trị viên. Tạo đơn bằng thông tin thử nghiệm, ghi lại mã đơn và dùng mã đó để đối chiếu trạng thái ở cả hai phiên.

Nếu dùng cơ sở dữ liệu Supabase khác đã có schema WashCare, áp dụng [migration Realtime](supabase/migrations/202611050005_orders_realtime.sql) để theo dõi cập nhật đơn và [migration COD](supabase/migrations/202611100001_cod_collection.sql) để xác nhận thu tiền.

## Kiểm thử Supabase cục bộ

```sh
npm install --prefix .dart_tool/momo-sql-check --no-save --no-package-lock --ignore-scripts @electric-sql/pglite
node --test supabase/tests/cod_collection_test.mjs supabase/tests/momo_sandbox_test.mjs
```

Các test dùng dữ liệu giả để kiểm tra luồng COD và khả năng tương thích với đơn MoMo cũ.

## Lịch sử phát triển và đóng góp

Dự án có [commit đầu tiên](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7/commit/7177ed6) ngày **12/10/2026**. Bảng dưới dùng tên tác giả trong Git và dẫn đến các commit tiêu biểu.

| Tác giả | Phần việc | Commit tiêu biểu |
| --- | --- | --- |
| nguyenbaoky1177 | Theo dõi đơn theo thời gian thực, tìm đơn và xác nhận thu COD | [8f64ab7](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7/commit/8f64ab7), [b427e4c](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7/commit/b427e4c) |
| HoangAn | Cải tiến giao diện, lời chào và trung tâm hỗ trợ | [3dadbcd](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7/commit/3dadbcd), [10651ce](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7/commit/10651ce) |
| Phuong Duy | Sổ địa chỉ và màn hình chi tiết đơn của khách | [55a6014](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7/commit/55a6014) |
| njan k nuy | Chuyển giao diện sáng/tối và ngôn ngữ Việt/Anh | [493cf6e](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7/commit/493cf6e) |
