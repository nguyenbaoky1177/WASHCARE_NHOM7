# Kế hoạch đóng góp nhóm WashCare

Cách làm hiện tại: mỗi thành viên tự đề xuất tính năng, báo nhóm để tránh trùng việc, làm trên nhánh riêng rồi gửi Pull Request. Không chỉnh Supabase (schema, SQL, RLS, RPC, Edge Functions hoặc cấu hình backend); vẫn được dùng luồng đọc/ghi dữ liệu sẵn có của ứng dụng. Ba phần dưới đây là phương án tham khảo nếu thành viên cần gợi ý, không phải phân công bắt buộc. Mỗi bạn tự thực hiện, kiểm thử và giải thích được phần mình làm. Giữ nguyên lịch sử và tác giả commit hiện có.

## 1. Chuẩn bị — nguyenbaoky1177

- Mời lại PDuy26725 vì lời mời trước đã hết hạn; yêu cầu cả nhóm xác nhận truy cập.
- Chạy flutter analyze và flutter test trên bản hiện tại.
- Rà diff và commit các sửa đổi đang có trên máy theo nội dung thực tế, sau đó push. Không chuyển các thay đổi đã làm sang tên thành viên khác.
- Gửi cả nhóm link repo và mã commit làm mốc bắt đầu. Các thành viên chỉ clone/pull sau khi bản này đã lên GitHub.
- Sau khi thống nhất đề xuất của từng thành viên, tạo GitHub Issue tương ứng và giao người thực hiện. Issues là bảng việc, không thay thế commit/PR.
- Không sửa đồng thời các file đã giao cho thành viên. Nếu phát hiện lỗi liên quan, trao đổi trước trong PR.

## 2. An23-aa — giỏ dịch vụ, lưu đơn đang soạn

Tiêu đề Issue: Thêm giỏ dịch vụ lưu riêng theo tài khoản trên thiết bị

Nhánh: feature/service-cart

Phạm vi file:
- Tạo lib/core/cart_service.dart và model giỏ nếu cần.
- Tạo lib/pages/cart_page.dart.
- Chỉnh lib/pages/home_page.dart để thêm dịch vụ vào giỏ và mở giỏ.
- Chỉnh lib/pages/order_page.dart để nhận danh sách số lượng ban đầu từ giỏ, giữ tương thích với const OrderPage() đang dùng.
- Tạo test/cart_service_test.dart; thêm widget test nếu cần kiểm tra nút/điều hướng.

Luồng sử dụng:
Trang chủ → Thêm vào giỏ → Xem giỏ, chỉnh số lượng → Tiếp tục đặt đơn → Chọn lịch và thông tin giao nhận → Xác nhận theo luồng đặt đơn hiện có.

Yêu cầu:
1. Thêm dịch vụ; thêm lại cùng dịch vụ thì tăng số lượng, không tạo dòng trùng. Có tăng/giảm và xóa từng mục, xác nhận trước khi xóa toàn bộ.
2. Lưu ID dịch vụ và số lượng bằng AccountStorage sẵn có. Giỏ riêng theo tài khoản; đóng/mở app vẫn giữ trên cùng thiết bị. Không lưu bản sao giá để dùng cho đơn mới.
3. Hiện tổng tiền dịch vụ tạm tính từ danh mục hiện tại. Chưa cộng voucher/phí giao hoặc gọi đây là tổng thanh toán cuối cùng.
4. Khi tải lại giỏ và trước khi chuyển sang đặt đơn, lấy danh mục mới bằng luồng ServiceCache hiện có. Nếu giá đổi thì cập nhật và báo rõ; dịch vụ đã tạm ngưng/không tồn tại phải được báo và bỏ khỏi phần có thể đặt. Không âm thầm đặt dịch vụ thay thế.
5. Không có mạng để kiểm tra danh mục thì báo thử lại; không dùng cache giá làm căn cứ xác nhận đơn. Giữ giỏ để khách quay lại.
6. OrderPage nhận bản sao số lượng hợp lệ từ giỏ. Khách vẫn phải chọn lịch và kiểm tra thông tin trước khi đặt. Không tạo đơn ngay khi bấm Tiếp tục đặt đơn.
7. Quay lại từ trang đặt đơn không mất giỏ. Đơn tạo thất bại giữ nguyên giỏ. Khi RPC tạo đơn đã thành công thì xóa các mục đã đặt; kết quả thanh toán sau đó không tạo lại giỏ cho đơn đã tồn tại. Không xóa những mục khách mới thêm trong lúc chờ yêu cầu tạo đơn.
8. Không đổi công thức giá, voucher, MoMo hoặc payload/RPC tạo đơn. Giỏ không lưu thông tin thanh toán, lịch hẹn hay voucher cũ.

Tiêu chí hoàn thành:
- Test thêm trùng, tăng/giảm/xóa, dữ liệu lưu lỗi, lưu và đọc lại, cách ly hai tài khoản và không ghi mất dữ liệu khi bấm nhanh.
- Kiểm tra dịch vụ ngừng hoạt động, giá thay đổi, giỏ trống, lỗi mạng, quay lại từ checkout và tạo đơn thành công/thất bại.
- Chạy flutter analyze và flutter test; PR có ảnh giỏ và kết quả kiểm tra trên máy ảo.

Giới hạn: lưu trên thiết bị theo tài khoản, chưa đồng bộ sang máy khác. Không thay đổi Supabase schema, SQL, RLS, RPC hoặc Edge Functions.

## 3. tuanphat205 — tra cứu lịch sử đơn hàng

Tiêu đề Issue: Tìm và lọc lịch sử đơn theo mã, trạng thái và khoảng ngày

Nhánh: feature/order-history-filters

Phạm vi file:
- Chỉnh lib/pages/order_history_page.dart.
- Tạo lib/core/order_history_filter.dart để tách logic lọc.
- Tạo test/order_history_filter_test.dart.

Yêu cầu:
1. Thêm ô tìm mã đơn, chấp nhận cách nhập 16 hoặc #16; so khớp đúng mã sau khi bỏ dấu # và khoảng trắng. Ô trống không giới hạn mã; mã không hợp lệ không gây crash.
2. Bộ lọc trạng thái dùng đúng các trạng thái hiện có: tất cả, pending, confirmed, washing, delivering, completed, cancelled; giao diện dùng nhãn tiếng Việt.
3. Chọn khoảng ngày theo ngày tạo đơn created_at, không theo lịch lấy đồ; hiển thị rõ điều này.
4. Kết hợp đồng thời mã đơn, trạng thái và ngày; có nút Xóa bộ lọc đưa về mặc định. Hủy chọn ngày không làm mất lựa chọn trước.
5. Lọc trên danh sách đơn của chính tài khoản đã tải. Giữ nguyên điều kiện user_id trong truy vấn; không sửa nguồn dữ liệu để đọc đơn người khác.
6. Ngày tính theo giờ địa phương; bao gồm cả ngày bắt đầu/kết thúc. Dùng đầu ngày bắt đầu và đầu ngày sau ngày kết thúc làm giới hạn. Nếu không có created_at hợp lệ thì không khớp bộ lọc ngày, không gây lỗi.
7. Hiện số kết quả, thông báo không tìm thấy; phân biệt danh sách gốc trống với lỗi tải mạng. Kéo làm mới giữ các bộ lọc đang chọn.
8. Giữ nguyên cách xem thông tin đơn, không thêm hủy/đổi trạng thái hoặc thay đổi giá.

Tiêu chí hoàn thành:
- Test mã 16/#16, mã sai, trạng thái, đầu/cuối ngày, dữ liệu rỗng, ngày không hợp lệ và tổ hợp ba điều kiện.
- Thử bộ lọc trên máy ảo; kiểm tra refresh và xóa bộ lọc.
- Chạy flutter analyze và flutter test; PR có ảnh và kết quả thực tế.

Không sửa Supabase schema, SQL, RLS, RPC hoặc truy vấn tạo đơn.

## 4. PDuy26725 — thống kê admin theo khoảng thời gian

Tiêu đề Issue: Thống kê đơn và tổng tiền đơn hoàn thành theo ngày tạo

Nhánh: feature/dashboard-date-filter

Phạm vi file:
- Chỉnh lib/pages/admin/admin_hub_page.dart, chỉ phần AdminDashboardView; giữ điều hướng AdminHubPage.
- Tạo lib/core/order_statistics.dart.
- Tạo test/order_statistics_test.dart.

Yêu cầu:
1. Thêm Tất cả / Hôm nay / 7 ngày gần nhất / Khoảng ngày tùy chọn. Mặc định Tất cả như hiện tại.
2. Lọc theo created_at, ghi rõ Thống kê theo ngày tạo đơn. Đây là tổng tiền đơn hoàn thành trong tập đơn được chọn, chưa phải báo cáo tiền đã thu hoặc doanh thu theo ngày hoàn thành.
3. Theo ngày địa phương trên thiết bị. 7 ngày gồm hôm nay và 6 ngày trước; khoảng tùy chọn bao gồm cả ngày cuối bằng mốc đầu ngày kế tiếp. Xử lý created_at thiếu/không hợp lệ.
4. Số đơn từng trạng thái và tổng tiền đều dùng cùng tập đơn sau lọc. Chỉ cộng totalPrice của đơn completed; không cộng pending/cancelled.
5. Danh sách đơn gần đây trong dashboard nếu có cũng lọc theo khoảng đã chọn. Chỉ số đánh giá lấy riêng vẫn giữ toàn bộ thời gian, ghi nhãn rõ; không sửa ReviewService hoặc giả vờ đã lọc đánh giá theo ngày.
6. Không có đơn thì hiển thị 0 và thông báo phù hợp. Hủy date picker giữ lựa chọn trước; refresh giữ khoảng ngày.
7. Logic tính toán tách khỏi widget; nhận thời điểm tham chiếu để test không phụ thuộc ngày máy đang chạy. Không tự đổi dữ liệu đơn và không sửa OrderModel.

Tiêu chí hoàn thành:
- Test hôm nay, 7 ngày, khoảng tùy chọn, ranh giới ngày/múi giờ, thiếu ngày, dữ liệu rỗng và chỉ cộng đơn completed.
- Thử trên máy ảo ít nhất hai khoảng ngày; đối chiếu số liệu với các đơn thực tế đang có.
- Chạy flutter analyze và flutter test; PR có ảnh cùng quy tắc tính rõ ràng.

Không sửa Supabase schema, SQL, RLS, RPC hoặc dữ liệu đơn. Các đơn thử hiện tại vẫn được tính nếu nằm trong khoảng; chưa thêm chức năng loại đơn thử.

## Giới hạn chung của ba Issue

- Không sửa bất kỳ file nào trong supabase/, không chạy migration mới, không đổi backend.
- Không thêm package nếu Flutter, SharedPreferences và các tiện ích hiện có đáp ứng được.
- Mỗi người chỉ sửa phạm vi được giao. File mới mang tên riêng nên ít conflict. Nếu cần sửa file khác thì trao đổi chủ nhóm trước.
- Chỉ chủ nhóm bổ sung README tổng hợp sau khi review PR để tránh cả nhóm cùng sửa một file.
- Các tính năng trên là kế hoạch để thành viên tự thực hiện, chưa phải tính năng đã có hoặc đã kiểm thử.

## 5. Quy trình mỗi thành viên

Cấu hình danh tính một lần trong repository, dùng email gắn với tài khoản GitHub của chính mình:

```powershell
git config user.name "Ten cua ban"
git config user.email "email-cua-ban"
git config --get user.name
git config --get user.email
```

Lần đầu tải dự án:

```powershell
git clone https://github.com/nguyenbaoky1177/WASHCARE_NHOM7.git
cd WASHCARE_NHOM7
git switch main
git pull --ff-only origin main
```

Tạo nhánh đúng tên ở phần mình được giao, ví dụ cho An:

```powershell
git switch -c feature/service-cart
flutter pub get
```

Sau khi tự làm xong:

```powershell
dart format <cac-file-Dart-minh-da-sua>
flutter analyze
flutter test
git status --short
git diff
```

Các dấu <...> là chỗ thay bằng đường dẫn thực tế, không chép nguyên để chạy. Chỉ git add các file thuộc phần việc của mình; bổ sung đường dẫn model/widget mới nếu có. Ví dụ cho An sau khi đã tạo đủ các file:

```powershell
git add lib/core/cart_service.dart lib/pages/cart_page.dart lib/pages/home_page.dart lib/pages/order_page.dart test/cart_service_test.dart
git commit -m "feat: add persistent service cart"
git push -u origin feature/service-cart
```

Mở Pull Request trên GitHub: base main, compare nhánh của mình. Ghi vấn đề, thay đổi, kết quả kiểm thử và ảnh nếu đổi giao diện; liên kết Issue bằng Closes #so-issue. Không ghi đã test nếu chưa chạy.

Chia commit theo thay đổi có ý nghĩa; không cần đạt số lượng commit cố định. Không force push, reset lịch sử hoặc đổi tác giả để tạo đóng góp. Nếu pull/merge báo conflict, dừng và gửi chủ nhóm tên file cùng thông báo; không chọn ghi đè toàn bộ file.

## 6. Chủ nhóm review và tích hợp

- Mỗi PR kiểm tra đúng phạm vi, xem diff, chạy analyze và test; chạy ứng dụng nếu có đổi giao diện.
- Merge lần lượt từng PR. Có thể dùng Create a merge commit để giữ các commit của thành viên.
- Sau khi merge, các bạn cập nhật main trước khi nhận việc tiếp theo.
- Cuối cùng chủ nhóm pull main, chạy lại analyze, test, build APK và thử luồng demo trên máy ảo.
- Chủ nhóm bổ sung README với hướng dẫn chạy, thành viên/MSSV, phần việc thực tế và link PR; không chỉ danh sách tài khoản được mời. Không ghi khóa hoặc mật khẩu vào README.

## 7. Đổi repository thành Public

Chủ repo thực hiện trên GitHub:
1. Vào WASHCARE_NHOM7 → Settings → General.
2. Cuộn xuống Danger Zone → Change repository visibility → Change visibility.
3. Chọn đổi sang Public và làm theo các bước xác nhận GitHub hiển thị.
4. Mở https://github.com/nguyenbaoky1177/WASHCARE_NHOM7 bằng cửa sổ ẩn danh, kiểm tra xem được Code, commit và Pull Requests.

Trước khi công khai, rà cả mã hiện tại và lịch sử Git để tránh công khai mật khẩu, service_role key, MoMo Secret Key, token, .env, khóa ký Android hoặc dữ liệu khách thật. Nếu bí mật từng được commit, chỉ xóa khỏi file hiện tại chưa đủ; phải thu hồi/đổi khóa và xử lý lịch sử phù hợp. Kế hoạch này không xác nhận đã kiểm tra sạch toàn bộ lịch sử.

Đổi Public không tự commit/push thay đổi đang nằm trên máy và không tạo đóng góp cho thành viên.
