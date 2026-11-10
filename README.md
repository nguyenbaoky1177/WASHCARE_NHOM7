# WashCare

Đồ án Flutter quản lý dịch vụ giặt ủi và giao nhận. Khách chọn dịch vụ, đặt lịch lấy đồ, thanh toán tiền mặt khi nhận đồ (COD), theo dõi và đánh giá đơn. Quản trị viên quản lý đơn, dịch vụ và tài khoản.

## Chạy trên Android

Tại thư mục dự án, dùng Flutter SDK phù hợp với yêu cầu Dart trong `pubspec.yaml`.

```sh
flutter pub get
flutter run
```

App dùng dự án Supabase được cấu hình trong `lib/supabase_config.dart`. Nếu dùng dự án Supabase khác, cấu hình URL và publishable key của dự án đó. Tài khoản admin phải được cấp vai trò trên máy chủ.

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

Xem [kịch bản demo và yêu cầu Supabase](supabase/DEMO_CHECKLIST.md), [migration xác nhận thu COD](supabase/migrations/202611100001_cod_collection.sql) và [lịch sử đóng góp trên GitHub](https://github.com/nguyenbaoky1177/WASHCARE_NHOM7/commits/main/).
