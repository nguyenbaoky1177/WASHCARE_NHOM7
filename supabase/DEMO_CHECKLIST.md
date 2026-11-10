# Kịch bản trình diễn WashCare

## Chuẩn bị

- Cài APK release phù hợp với kiến trúc Android. Dùng hai phiên đăng nhập riêng cho khách và quản trị viên.
- Trên cơ sở dữ liệu dự án đã có schema WashCare, kiểm tra bảng `orders` được bật Realtime bằng [migration 005](migrations/202611050005_orders_realtime.sql).
- Để demo xác nhận thu tiền, người có quyền quản trị Supabase chạy [migration COD](migrations/202611100001_cod_collection.sql) trong SQL Editor. Nếu thiếu migration, app báo chưa bật xác nhận thu tiền. Khách vẫn đặt và theo dõi đơn COD được.
- Khi demo trên hệ thống dùng chung, ghi chú rõ đơn thử nghiệm và dùng thông tin giao nhận giả.

## Các bước demo

1. Khách mở Trang chủ, chọn dịch vụ và số lượng, chọn lịch lấy đồ trong tương lai rồi chọn hoặc nhập địa chỉ. Kiểm tra tổng tiền, chọn COD và ghi lại mã đơn sau khi đặt.
2. Khách mở **Đơn hàng**, tìm bằng mã vừa tạo. Quản trị viên mở cùng đơn và lần lượt cập nhật **Đã xác nhận → Đang giặt → Đang giao → Hoàn thành**. Đối chiếu trạng thái trên phiên khách.
3. Sau khi đơn COD hoàn tất, admin xác nhận đã thu đủ tiền thử nghiệm. Đối chiếu số tiền, thời điểm, người ghi nhận và trạng thái thanh toán trên phiên khách.
4. Khách đánh giá đơn đã hoàn thành. Dùng một đơn thử khác đang chờ xác nhận để kiểm tra thao tác hủy.
5. Kiểm tra sổ địa chỉ, tìm mã không tồn tại, chuyển sáng/tối và đổi ngôn ngữ. Tài khoản khách chỉ xem được các đơn của mình.

## Kiểm thử tự động

```sh
flutter analyze
flutter test
npm install --prefix .dart_tool/momo-sql-check --no-save --no-package-lock @electric-sql/pglite
node --test supabase/tests/cod_collection_test.mjs supabase/tests/momo_sandbox_test.mjs
```

Test SQL dùng PostgreSQL nhúng với dữ liệu giả. Nó bao phủ tạo đơn, cập nhật trạng thái, thu COD, quyền truy cập và tương thích với dữ liệu MoMo cũ.

## Dữ liệu trình diễn đã có

| Đơn | Mục đích | Trạng thái ghi nhận trong lần kiểm thử trước |
| --- | --- | --- |
| 13 | Luồng xử lý và đánh giá | Hoàn thành, có đánh giá thử |
| 14 | Khách hủy đơn | Đã hủy |
| 15 | MoMo mô phỏng cũ | Chờ xử lý |
| 17 | Realtime COD | Đã hủy, nhận sự kiện INSERT và UPDATE |

Khi cần dọn dữ liệu, đối chiếu khách hàng và ghi chú `TEST_CODEX` trước khi thao tác. Đơn 16 do người dùng tạo. Thống kê quản trị có thể bao gồm các đơn thử này.
