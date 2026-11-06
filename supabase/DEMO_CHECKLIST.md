# Dữ liệu và các bước trình diễn

Các bản ghi do lần kiểm thử trước tạo (giữ lại để đối chiếu):

| Đơn | Mục đích | Trạng thái đã kiểm tra |
| --- | --- | --- |
| 13 | Luồng xử lý và đánh giá | Hoàn thành; có đánh giá thử |
| 14 | Khách hủy đơn | Đã hủy |
| 15 | MoMo mô phỏng cũ | Chờ xử lý; không phải giao dịch MoMo thật |
| 17 | Kiểm tra realtime COD | Đã hủy ngay; nhận đủ sự kiện INSERT và UPDATE |

Không xóa các đơn này bằng câu lệnh chỉ dựa vào ID. Khi cần dọn dữ liệu, đối chiếu cả khách hàng và ghi chú TEST_CODEX trước. Đơn 16 do người dùng tạo, không thuộc dữ liệu kiểm thử của trợ lý.

Hiện thống kê quản trị vẫn tính các bản ghi thử ở trên. Đây là dữ liệu trình diễn, không dùng để báo cáo doanh thu thực tế.

Trước khi trình diễn:

1. Chạy migration 202611050005_orders_realtime.sql trong SQL Editor để bật sự kiện bảng orders.
2. Dùng hai phiên riêng: một khách hàng và một admin. Khách tạo đơn COD; admin lần lượt xác nhận, giặt, giao, hoàn thành. Kiểm tra khách thấy trạng thái đổi mà không tải lại thủ công.
3. Khách đánh giá đơn hoàn thành; thử hủy một đơn còn chờ xác nhận.
4. Kiểm tra khách không thấy màn hình quản trị và không đọc được đơn của người khác.

Đã kiểm tra trực tiếp với phiên khách hiện tại: truy vấn đơn 13 trả danh sách rỗng; gọi RPC admin_set_user_role bị từ chối. Sau khi người dùng chạy migration 005, kết nối báo Subscribed to PostgreSQL. Phiên WebSocket kiểm thử nhận đúng INSERT pending và UPDATE cancelled của đơn thử 17. Chưa kiểm tra trực quan đồng thời trên hai thiết bị khách/admin.

MoMo Sandbox còn chờ thông tin tích hợp. Quên mật khẩu nằm ngoài phạm vi kiểm thử theo yêu cầu của người dùng.
