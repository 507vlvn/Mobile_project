# TASKS — App Game Hub (Rubik · Sudoku · Caro · Xếp hình)

> Danh sách công việc được chốt trước khi code. Đánh dấu `[x]` khi xong.
> Mỗi task có **AC** (Acceptance Criteria = điều kiện để coi là xong).
> Ưu tiên của đợt này: **trải nghiệm UI/UX**, đặc biệt là tương tác trực tiếp với khối Rubik.
>
> **Quy tắc:** Không commit hay push git bất cứ thứ gì. Việc quản lý git do bạn tự làm.
> **Chưa deploy:** chỉ chạy API trên máy cá nhân, trỏ tới DB somee.
>
> **Tiến độ (19/10/2026):** Xong P0–P11 (4 game, đăng nhập, lịch sử, xếp hạng, thách đấu, chat; backend + DB somee đã test đầu-cuối). Đang làm: nối chế độ thách đấu vào Sudoku/Xếp hình/Caro. Còn lại: P12 (rà soát cuối, xoá text.txt).

---

## Tóm tắt: các game sẽ làm

Ứng dụng là một **"Game Hub" trí tuệ**. Người chơi đăng nhập, chọn game từ màn Hub, chơi theo 3 mức Dễ / Vừa / Khó. Mỗi ván được tính điểm theo **thời gian** và **số lỗi**, rồi đưa lên **bảng xếp hạng**. Các game chạy offline trên máy; kết quả gửi lên server khi có mạng. App có cả giao diện sáng và tối.

- **Rubik 3D** (game chủ lực). Khối 3D tự vẽ, **chạm vào ô rồi vuốt để xoay tầng** giống như cầm khối thật. Có 2 chế độ:
  - **Luyện giải:** app xáo đề theo độ khó, người chơi tự giải. Có nút gợi ý (tô sáng tầng cần xoay và vẽ mũi tên). Mỗi lần dùng gợi ý tính 1 lỗi.
  - **Quét & giải:** dùng camera quét 6 mặt khối thật, kiểm tra lại trên sơ đồ trải phẳng, rồi app đưa ra lời giải từng bước có hoạt ảnh 3D.
- **Sudoku:** đề sinh tự động, luôn chỉ có một lời giải. Độ khó tính theo số ô cho sẵn. Có ghi chú nháp, gợi ý, hoàn tác. Điền sai thì tính lỗi.
- **Xếp hình (trượt ô số):** bảng 3×3 / 4×4 / 5×5 theo độ khó, đề luôn giải được. Lỗi là số bước đi nhiều hơn mức tối ưu.
- **Caro với máy:** bàn 15×15, 5 quân liên tiếp thì thắng. AI có 3 mức, từ đánh theo thế cờ đơn giản tới minimax. Mỗi lần đi lại tính lỗi.
- **Điểm cộng:** **Thách đấu** (hai người chơi cùng một đề, so điểm) và **Chat 1-1** với người chơi khác.

---

## 0. Các quyết định đã chốt

| # | Quyết định | Ghi chú |
|---|---|---|
| D1 | **"Xếp hình" = trò trượt ô số** (sliding puzzle 3×3 / 4×4 / 5×5) | Hợp với chữ "giải", đo được số bước và số lỗi |
| D2 | **Rubik có 2 tính năng:** (A) **Luyện giải**: app ra đề, người chơi tự vuốt để giải, có gợi ý; (B) **Quét & giải**: chụp 6 mặt rồi app giải (đã có, cần làm lại UX) | Cả hai dùng chung engine 3D có vuốt xoay tầng |
| D3 | **Thách đấu, Chat** là điểm cộng, làm sau cùng | |
| D4 | **Database trên somee** (SQL Server `doan_mobile`). **Chưa deploy API**, chỉ chạy trên máy cá nhân | Xem §2 về giới hạn số request |
| D8 | **Có cả giao diện sáng và tối**. Mặc định theo hệ thống, cho người dùng tự chọn | §1.1 |
| D9 | **Chưa có logo.** Tạm dùng tên chữ và icon mặc định, khi có logo thì thay | |
| D10 | **Không commit hay push git** | Bạn tự quản lý git |
| D5 | **Backend:** ASP.NET Core Web API (.NET 10 SDK đã có) + EF Core + JWT. **Flutter không bao giờ kết nối thẳng tới DB** | |
| D6 | **Các game chạy offline trên máy**, chơi xong mới gửi kết quả. **Server tự tính điểm** | |
| D7 | `text.txt` chỉ để xem chuỗi kết nối. **Xóa khi xong việc** (task P12.5) | Trong lúc làm, chuỗi kết nối đặt ở `appsettings.Development.json` (đã thêm vào `.gitignore`) |

---

## 1. Design system (căn cứ theo skill `ui-ux-pro-max`)

**Phong cách:** Gaming hiện đại, có **cả giao diện sáng và tối**. Mặc định theo cài đặt hệ thống; người dùng có thể chọn Hệ thống / Sáng / Tối trong Hồ sơ, lựa chọn được lưu lại.
Skill gợi ý Claymorphism hồng kèm font Caveat, nhưng **không dùng** vì font Caveat thiếu dấu tiếng Việt và mẫu đó dành cho landing page web.

Lưu ý khi làm 2 giao diện:
- Thiết kế hai giao diện **song song**, giao diện tối không phải là đảo màu của giao diện sáng.
- Kiểm tra độ tương phản **riêng cho từng giao diện**.
- Viền và đường kẻ phải nhìn rõ ở cả hai.
- **Màn quét camera luôn tối** ở cả hai giao diện, vì đó là thói quen chung của các app camera và giúp nhìn ảnh rõ hơn.
- Thân khối Rubik luôn là nhựa đen, nên sticker trắng vẫn nổi trên nền sáng.

### 1.1 Màu (lấy theo bảng *Gaming* của skill, chuyển thành token trong `ThemeData`/`ColorScheme`)

**Giao diện sáng:**
| Token | Hex | Dùng cho |
|---|---|---|
| primary | `#7C3AED` | Nút chính (chữ trắng trên nền tím đạt tương phản ~5.7:1) |
| onPrimary | `#FFFFFF` | |
| secondary | `#6D28D9` | Chip, nhấn phụ |
| accent | `#E11D48` | Huy hiệu, kỷ lục mới |
| background | `#F8F7FC` | Nền màn hình |
| surface / card | `#FFFFFF` | Thẻ, bottom sheet (có bóng đổ nhẹ) |
| surfaceVariant | `#F1EEF9` | Ô nhập, nền phụ |
| onSurface | `#0F172A` | Chữ chính |
| onSurfaceMuted | `#475569` | Chữ phụ (tương phản ≥ 4.5:1) |
| outline | `#DDD6FE` | Viền |
| error | `#DC2626` | Lỗi, luôn kèm icon/chữ |
| success | `#16A34A` | Hoàn thành, luôn kèm icon/chữ |

**Giao diện tối:**
| Token | Hex | Dùng cho |
|---|---|---|
| primary | `#7C3AED` | Nút chính, trạng thái đang chọn |
| onPrimary | `#FFFFFF` | |
| secondary | `#A78BFA` | Chip, nhấn phụ |
| accent (CTA thưởng) | `#F43F5E` | Huy hiệu, kỷ lục mới |
| background | `#0F0F23` | Nền màn hình |
| surface / card | `#1E1C35` | Thẻ, bottom sheet |
| surfaceVariant (muted) | `#27273B` | Ô nhập, nền phụ |
| onSurface | `#E2E8F0` | Chữ chính (tương phản ≥ 4.5:1) |
| onSurfaceMuted | `#94A3B8` | Chữ phụ |
| outline | `#4C1D95` | Viền |
| error | `#EF4444` | Lỗi, luôn kèm icon/chữ |
| success | `#22C55E` | Hoàn thành, luôn kèm icon/chữ |

- [ ] Kiểm tra lại độ tương phản thực tế của từng cặp chữ/nền **ở cả hai giao diện**. Không dùng chữ xám nhạt trên nền xám.
- 6 màu sticker Rubik giữ nguyên trong `RubikColors` (là dữ liệu, không phải màu theme).

### 1.2 Chữ
- Font **Be Vietnam Pro** (hỗ trợ tiếng Việt tốt), **đóng gói vào `assets/fonts/`** để chạy offline. Việc này cũng giải quyết luôn chuyện thư mục `assets/` đang trống.
- Thang cỡ chữ: 12 / 14 / 16 / 18 / 22 / 28 / 32. **Chữ nội dung ≥ 14, chữ nhỏ nhất ≥ 12.** Màn quét hiện đang dùng 8.5–11px, phải sửa.
- Đồng hồ, điểm, số bước dùng **chữ số đều độ rộng** (`FontFeature.tabularFigures()`) để con số không bị nhảy khi đổi giá trị.

### 1.3 Quy tắc tương tác (CRITICAL theo skill)
- Vùng chạm **≥ 48×48dp**, khoảng cách giữa các nút ≥ 8dp. Các chấm màu 25px và nút xoay lưới hiện tại đều quá nhỏ.
- Có phản hồi khi nhấn trong vòng 100ms (ripple hoặc thu nhỏ còn 0.95).
- **Rung nhẹ** (`HapticFeedback.selectionClick`) khi một tầng Rubik khớp vào vị trí và khi hoàn thành ván. Không lạm dụng.
- **Mỗi vùng chỉ có 1 cử chỉ chính**, không để chạm-tô màu và vuốt-xoay tầng tranh nhau trong cùng một chế độ.
- **Mọi thao tác vuốt đều phải có nút thay thế** (bảng nút R U F L D B).
- Hiệu ứng chuyển động phải **ngắt được giữa chừng** và không chặn thao tác của người dùng. Tôn trọng cài đặt giảm chuyển động (`MediaQuery.disableAnimations`).
- **Không dùng emoji làm icon.** Đang có 📌 🧭 ✓ trong code, cần thay bằng Material Icons (Rounded).
- Mỗi màn hình chỉ có **một nút hành động chính (CTA)**.
- Thời lượng hiệu ứng thống nhất qua token: `fast` 120ms · `normal` 220ms · `slow` 350ms. Hiệu ứng lúc thoát ngắn hơn lúc vào.

### 1.4 Điều hướng
- Thanh điều hướng dưới có 4 mục, mỗi mục có cả icon và chữ: **Trò chơi · Xếp hạng · Bạn bè** (gồm Thách đấu và Chat) **· Hồ sơ**.
- Nút Back phải đoán trước được. Khi rời một màn đang có dữ liệu chưa lưu (ván đang chơi, đang quét), phải **hỏi xác nhận**.

---

## 2. Quy tắc làm việc với somee (tránh bị khóa tài khoản)

- [ ] **Không** chạy load test, **không** gửi request song song khi test. Script test phải gọi **tuần tự**, nghỉ ≥ 300ms giữa các lần gọi.
- [ ] Chuỗi kết nối đặt `Max Pool Size=10` để giới hạn số kết nối.
- [ ] Tạo bảng bằng **một file script SQL chạy một lần**. Không chạy `dotnet ef database update` lặp đi lặp lại.
- [ ] Phía client: **debounce** (gom nhiều lần bấm liên tiếp) cho ô tìm kiếm; không gọi API trong vòng lặp. Thử lại tối đa 3 lần, thời gian chờ tăng dần (1s, 2s, 4s).
- [ ] Bảng xếp hạng và danh sách: lưu tạm 30–60 giây ở client; có kéo xuống để làm mới, không tự làm mới liên tục.
- [ ] Chat: ưu tiên SignalR. Nếu somee không hỗ trợ WebSocket thì hỏi tin mới **mỗi ≥ 5 giây và chỉ khi đang mở màn chat**.
- [ ] API chạy trên máy cá nhân, trỏ tới DB somee. **Chưa deploy.**

---

## 3. Danh sách task

### P0 — Chuẩn bị & bảo mật
- [x] **P0.1** Thêm vào `.gitignore`: `text.txt`, `**/appsettings.Development.json`, `*.env`. Chỉ sửa file, **không commit**
- [x] **P0.2** Giữ nguyên các thay đổi đang dở trong `lib/scanner/*` (phần sửa hướng sensor đã kiểm tra là đúng) và làm tiếp trên đó
- [x] **P0.3** Tạo thư mục `assets/fonts/` và thêm font Be Vietnam Pro, khai báo trong `pubspec.yaml`
  - AC: clone sạch về chạy `flutter pub get` rồi `flutter build apk --debug` không lỗi

### P1 — Khung ứng dụng & giao diện chung
- [x] **P1.1** `lib/core/theme/`: `AppColors` (bộ màu sáng và tối, mở rộng bằng `ThemeExtension` cho các màu success/accent/muted), `AppTextStyles`, `AppSpacing` (4/8/12/16/24/32), `AppMotion` (thời lượng, đường cong), `AppTheme.light()` và `AppTheme.dark()`
- [x] **P1.1b** `ThemeController`: chọn chế độ Hệ thống / Sáng / Tối, lưu bằng `shared_preferences`, đổi giao diện có hiệu ứng chuyển mượt. Đặt nút chọn ở màn Hồ sơ (dạng `SegmentedButton`)
  - AC: chuyển qua lại giữa sáng và tối thì mọi màn đều đọc rõ, không còn màu viết cứng chỉ hợp với một giao diện
- [x] **P1.1c** Icon app và splash **tạm thời**: dùng icon mặc định và tên chữ. Khi có logo thì thay
- [x] **P1.2** Cấu trúc thư mục theo từng tính năng: `lib/core/`, `lib/features/{rubik,sudoku,sliding,caro,auth,leaderboard,social,profile}/`. Chuyển code Rubik hiện có vào `features/rubik/`
- [x] **P1.3** Chuyển quản lý trạng thái từ `scoped_model` sang `provider` (cách dùng gần giống, nên chuyển nhẹ nhàng). Bỏ dữ liệu mẫu viết cứng trong `DataState`
- [x] **P1.4** App shell: thanh điều hướng dưới 4 mục và **màn Hub chọn game**: thẻ game có icon, tên, kỷ lục cá nhân, nút "Chơi"
- [x] **P1.5** Bộ widget dùng chung: `PrimaryButton` (có trạng thái đang tải và bị vô hiệu), `GameTimer` (chữ số đều độ rộng, tạm dừng được), `StatChip`, `ResultSheet` (màn kết quả: thời gian, số lỗi, điểm, nút Chơi lại / Về Hub), `ConfirmExitDialog`, `EmptyState`, `ErrorState` (có nút Thử lại)
- [x] **P1.6** Chọn độ khó dùng chung: `SegmentedButton` Dễ / Vừa / Khó, nhớ lần chọn gần nhất
  - AC: mọi màn đều dùng token theme, không còn mã màu hex viết rời rạc trong widget

### P2 — Engine Rubik: vuốt để xoay tầng ⭐ (trọng tâm UX)
**Mục tiêu:** Người dùng **đặt ngón tay lên một ô rồi vuốt** thì tầng tương ứng xoay theo ngón tay. Thả tay ra thì tầng tự khớp vào góc 90° gần nhất. Vuốt nhanh thì xoay luôn một nấc 90°.

- [x] **P2.1 Tách hình học ra khỏi painter:** tạo `CubeGeometry`, tính danh sách đa giác **một lần cho mỗi khung hình**. Dùng chung cho cả vẽ và xác định ô được chạm. Bỏ kiểu hit-test qua callback trong `paint()` như hiện tại
- [x] **P2.2 Mô hình hỗ trợ xoay tầng giữa M / E / S** (và nếu cần thì cả xoay nguyên khối x / y / z) trong `Cube3DState`. Bộ giải vẫn chạy đúng vì nó nhận diện mặt theo **màu tâm hiện tại**
- [x] **P2.3 Painter nhận tham số `LayerTurn(axis, layer, angle)`** với góc tùy ý (thay cho kiểu `activeMove` + `progress`) để tầng bám theo ngón tay
- [x] **P2.4 Nhận diện cử chỉ** (`RubikGestureController`):
  1. Lúc chạm xuống: tìm ô bị chạm, lấy ra viên lập phương nhỏ (x, y, z) và pháp tuyến `n` của mặt đó
  2. Chưa xử lý gì cho tới khi ngón tay đi được **10dp** (ngưỡng chống vuốt nhầm)
  3. Lấy 2 trục nằm trong mặt phẳng của mặt đó, chiếu lên màn hình, chọn trục `a` cùng hướng nhất với hướng vuốt. Trục quay `r = n × a`. Tầng cần xoay là tọa độ của viên đó theo trục `r`. Chiều quay lấy theo dấu tích vô hướng
  4. Trong lúc kéo: góc = độ dài vuốt chiếu lên trục ÷ (kích thước khối × hệ số), giới hạn trong ±180°
  5. Lúc thả tay: nếu vận tốc > ~600 dp/s thì xoay tiếp một nấc theo chiều vuốt; nếu không thì làm tròn về nấc 90° gần nhất (tròn về 0 nghĩa là bật về chỗ cũ). Hiệu ứng khớp vào chỗ dùng spring hoặc easeOut, 150–250ms, kèm rung nhẹ khi khớp
  6. Đổi thành ký hiệu nước đi (R/L/U/D/F/B/M/E/S kèm ' hoặc 2) rồi gọi `applyMove`, đẩy vào lịch sử nước đi
- [x] **P2.5 Phân vùng cử chỉ:** vuốt bắt đầu **trên ô màu** thì xoay tầng; vuốt bắt đầu **ở nền** hoặc **dùng hai ngón** thì xoay góc nhìn; chạm đúp ở nền thì đặt lại góc nhìn
- [x] **P2.6 Ngắt hiệu ứng giữa chừng:** đang trong hiệu ứng khớp mà chạm tiếp thì kết thúc ngay hiệu ứng cũ rồi nhận cử chỉ mới
- [x] **P2.7 Bảng nút thay thế** `MovePad` (6 mặt và nút chuyển chiều ', mỗi nút ≥ 48dp). Có thể thu gọn
- [x] **P2.8 Hoàn tác / Làm lại** theo lịch sử nước đi
- [x] **P2.9 Unit test** (bắt buộc, vì đây là phần dễ sai nhất):
  - Với mọi nước đi: làm nước đi rồi làm nước ngược thì về trạng thái ban đầu; làm 4 lần cùng một nước cũng về ban đầu
  - **Ánh xạ cử chỉ khớp với `applyMove`:** giả lập vuốt trên từng mặt, từng hướng, kết quả phải đúng nước đi mong đợi
  - Xáo ngẫu nhiên, đưa cho bộ giải, áp lời giải vào thì khối phải về trạng thái đã giải
  - Các tầng giữa M/E/S sau khi xoay vẫn giải được
- AC: chạy mượt 60fps trên máy thật; vuốt tầng nào thì xoay đúng tầng đó ở mọi góc nhìn; không xảy ra việc vừa xoay tầng vừa xoay góc nhìn cùng lúc

### P3 — Rubik (A): Luyện giải — app ra đề, người chơi tự giải
- [x] **P3.1** Màn chọn: **Luyện giải** / **Quét & giải** (2 thẻ lớn, mỗi thẻ có một dòng mô tả)
- [x] **P3.2** Sinh đề theo độ khó: Dễ 4–6 nước · Vừa 10–12 · Khó 20–25. Không sinh hai nước liên tiếp cùng một mặt, không sinh nước thừa kiểu R rồi R'. Có **hiệu ứng xáo** (chạy nhanh các nước, bỏ qua được)
- [x] **P3.3** HUD gồm: đồng hồ (**bắt đầu chạy từ nước đi đầu tiên**), số nước đi, số gợi ý đã dùng, nút Tạm dừng. Khi tạm dừng thì làm mờ khối để chống gian lận
- [x] **P3.4** *(Đã làm: thay mũi tên bằng hiệu ứng tầng sáng viền + "nhún" theo chiều cần xoay, kèm thẻ mô tả nước đi)* **Gợi ý:** chạy bộ giải Kociemba với trạng thái hiện tại để lấy nước tiếp theo. **Tô sáng tầng cần xoay và vẽ mũi tên chỉ chiều trên mặt 3D** (nếu khó làm thì tạm dùng chip chữ kèm tô sáng tầng). Mỗi lần gợi ý tính **+1 lỗi**
- [x] **P3.5** Nút **"Xem lời giải"**: mở trình phát lời giải (P4.5). Ván này tính **là bỏ cuộc**, không được điểm
- [x] **P3.6** Phát hiện khối đã giải (cả 6 mặt đồng màu): hiệu ứng mừng nhẹ, rung, hiện `ResultSheet`, gửi kết quả (P6)
- [x] **P3.7** Lưu ván đang chơi xuống máy (`shared_preferences`) để thoát app vẫn chơi tiếp được
- [x] **P3.8** Hướng dẫn lần đầu: 3 bước ngắn, gồm hình minh họa "đặt ngón tay lên ô → vuốt", bỏ qua được và không hiện lại
- AC: người chưa từng dùng app tự xoay được tầng trong vòng 10 giây kể từ lần đầu mở mà không cần đọc chữ

### P4 — Rubik (B): Quét & giải — làm lại UX
- [x] **P4.1** Sửa các lỗi đã tìm thấy: góc khung ngắm dưới-phải (`camera_scanner_view.dart:1430`); **nút Back làm mất dữ liệu quét** (dùng `PopScope` để hỏi xác nhận); `dispose()` gọi `_stopLiveStream()` mà không chờ xong; xóa ảnh tạm `_sq.jpg`
- [x] **P4.2** Tăng cỡ chữ lên ≥ 12 và vùng chạm lên ≥ 48dp (chấm màu, nút xoay lưới). Thay emoji bằng icon
- [x] **P4.3** **Màn "Kiểm tra lại"** sau khi quét xong 6 mặt: hiện **sơ đồ trải phẳng 2D** cùng **bộ đếm từng màu** (ví dụ "Đỏ 10/9" tô đỏ). Chạm vào ô để sửa. Nút Giải bị khóa cho tới khi hợp lệ
- [x] **P4.4** Báo lỗi cụ thể thay vì chỉ "mẫu màu không hợp lệ": sai số lượng màu, trùng tâm, hoặc lỗi lật cạnh/xoay góc (gợi ý mặt có thể đã quét sai hướng)
- [x] **P4.5** Trình phát lời giải (`solve.dart`): **tô sáng tầng và vẽ mũi tên trước khi xoay**; phần mô tả nước đi phải **lấy màu theo tâm hiện tại** thay vì viết cứng (Phải = Xanh lá…); bấm vào một nước trong danh sách để nhảy tới; nút Phát/Tạm dừng luôn bấm được
- [x] **P4.6** Chế độ "Nhập tay" (tô màu trên 3D) tách thành **chế độ riêng** có công tắc, để không lẫn với vuốt xoay tầng
- AC: quét đủ 6 mặt của một khối thật, ra lời giải, làm theo thì khối được giải (thử trên ít nhất 3 lần xáo khác nhau)

### P5 — Backend & Đăng ký/Đăng nhập (2đ)
- [x] **P5.1** File `db/schema.sql` theo sơ đồ **đã sửa**:
  - Đổi các khóa ngoại sang `ON DELETE NO ACTION` để tránh lỗi nhiều đường cascade (1785) ở `Challenges`, `Messages`, `History`
  - Xóa user bằng cờ `is_active` (xóa mềm)
  - Sửa `GameLevels.difficulty` thành `INT CHECK (1–3)`, không phải khóa ngoại
  - Bảng `History` thêm `challenge_id`, `result`, `moves_count`, `hints_used`
  - Bảng `Challenges` thêm `level_id`, `accepted_at`, `completed_at`, cùng các ràng buộc CHECK
  - Thêm index và VIEW cho bảng xếp hạng
  - Dữ liệu mẫu cho `Games` (RUBIK, SUDOKU, PUZZLE, CARO) và `GameLevels`
- [x] **P5.2** Chạy script **một lần** trên somee bằng `sqlcmd` (đã có sẵn trên máy)
- [x] **P5.3** Project `backend/GameHub.Api`: EF Core, Swagger, middleware xử lý lỗi chung trả về dạng ProblemDetails, CORS, `appsettings.Development.json` (đã gitignore)
- [x] **P5.4** API xác thực: `POST /api/auth/register`, `POST /api/auth/login` (trả JWT), `GET /api/users/me`, `PUT /api/users/me`. Mật khẩu băm bằng BCrypt; kiểm tra dữ liệu đầu vào; giới hạn số lần đăng nhập sai
- [x] **P5.5** Flutter: `ApiClient` (Dio, tự gắn token, gặp lỗi 401 thì đưa về màn đăng nhập, quá thời gian chờ thì cho thử lại), `TokenStorage` (`flutter_secure_storage`)
- [x] **P5.6** UI Đăng nhập / Đăng ký:
  - Mỗi ô có nhãn hiển thị rõ (không chỉ dùng chữ mờ gợi ý)
  - Kiểm tra lỗi khi rời khỏi ô; báo lỗi ngay dưới ô đó
  - Nút ẩn/hiện mật khẩu; cho phép trình quản lý mật khẩu tự điền (autofill)
  - Nút có trạng thái đang tải
  - Bàn phím đúng loại: email, mật khẩu
- [x] **P5.7** Chế độ **Chơi khách**: các game vẫn chơi được, chỉ không lưu điểm. Khi muốn lưu thì mời đăng nhập
- AC: đăng ký, đăng nhập, tắt app mở lại vẫn còn đăng nhập; nhập sai thì nhận thông báo rõ ràng kèm cách sửa

### P6 — Tính điểm & lịch sử (1đ)
- [x] **P6.1** Công thức (tính ở server): `score = max(base[độ khó] − số giây − số lỗi × 50, base × 10%)`, với base = 1000 / 2000 / 3000. Ván bỏ cuộc thì `score = 0`
- [x] **P6.2** Định nghĩa **lỗi**:
  - Sudoku: số lần điền sai
  - Xếp hình: số bước nhiều hơn mức tối ưu
  - Caro: số lần đi lại, cộng thêm kết quả thắng/thua
  - Rubik: số lần dùng gợi ý
- [x] **P6.3** `POST /api/history` (server tự tính điểm, chặn giá trị vô lý như thời gian âm), `GET /api/history/me`
- [x] **P6.4** Mất mạng thì **xếp kết quả vào hàng đợi** trên máy, gửi lại khi có mạng (gửi tuần tự từng cái)
- [x] **P6.5** Màn Lịch sử trong Hồ sơ: danh sách cuộn lười, lọc theo game, có màn trống khi chưa có dữ liệu

### P7 — Sudoku (2đ)
- [x] **P7.1** Bộ sinh đề bằng backtracking, **kiểm tra đề chỉ có duy nhất một lời giải**. Số ô cho sẵn: Dễ ~40, Vừa ~32, Khó ~26. Chạy trong isolate
- [x] **P7.2** UI: lưới 9×9 với đường viền khối 3×3 đậm hơn; tô sáng cùng hàng, cột, khối và các ô cùng số; bàn phím số từ 1–9 (≥ 48dp, kèm số lượng còn lại của từng số); chế độ ghi chú nháp; tẩy; hoàn tác; gợi ý
- [x] **P7.3** Điền sai thì ô chuyển đỏ **kèm icon**, rung nhẹ, +1 lỗi. Số đã đủ 9 lần thì nút số đó mờ đi
- [x] **P7.4** Kết thúc ván: `ResultSheet` và gửi kết quả
- [x] **P7.5** Unit test: bộ sinh đề luôn ra đề có duy nhất một lời giải

### P8 — Bảng xếp hạng (2đ)
- [x] **P8.1** `GET /api/leaderboard?gameCode=&difficulty=&period=all|week&top=50` và `GET /api/leaderboard/me`
- [x] **P8.2** UI: tab theo từng game, `SegmentedButton` chọn độ khó, 3 người đầu hiển thị nổi bật, **dòng của mình luôn dính ở cuối màn** kể cả khi ngoài top 50, kéo xuống để làm mới, hiệu ứng khung xương (skeleton) khi đang tải, màn lỗi có nút thử lại
- [x] **P8.3** Lưu tạm ở client 60 giây (theo §2)

### P9 — Caro với máy (1đ)
- [x] **P9.1** Bàn 15×15 (zoom/kéo được), 5 quân liên tiếp thì thắng. Đánh dấu nước vừa đi; khi thắng thì vẽ đường nối 5 quân
- [x] **P9.2** AI chạy trong isolate. Dễ: đánh giá theo thế cờ, có pha ngẫu nhiên. Vừa: chấm điểm theo thế 2/3/4 quân. Khó: minimax kèm alpha-beta, độ sâu 2–3, chỉ xét các ô gần quân đã đánh. Hiện "Máy đang nghĩ…" nếu mất hơn 300ms
- [x] **P9.3** Đi lại (tính lỗi), chọn ai đi trước
- [x] **P9.4** Unit test: nhận diện thắng ở cả 4 hướng; AI luôn chặn khi đối thủ có 4 quân

### P10 — Xếp hình / trượt ô số (1đ)
- [x] **P10.1** Kích thước 3×3 / 4×4 / 5×5 theo độ khó. Xáo bằng các nước đi hợp lệ từ trạng thái đã giải, nên luôn giải được
- [x] **P10.2** Chạm vào ô hoặc vuốt để trượt; có hiệu ứng trượt; có nút hoàn tác
- [x] **P10.3** Số bước tối ưu: với 3×3 dùng A* (heuristic Manhattan); với 4×4 trở lên dùng số bước xáo làm mốc. Lỗi = số bước thực tế − mốc
- [ ] **P10.4** (Tùy chọn) Chế độ dùng ảnh thay cho số

### P11 — Điểm cộng: Thách đấu & Chat
- [x] **P11.1** Thách đấu **không đồng thời**:
  1. Tạo lời thách, trạng thái `PENDING`
  2. Đối thủ chấp nhận, trạng thái `ACCEPTED`
  3. Hai bên chơi **cùng một đề** (`level_id` hoặc seed), gửi kết quả kèm `challenge_id`
  4. Server chọn người thắng, trạng thái `COMPLETED`
- [x] **P11.2** UI: danh sách lời thách đến/đi có huy hiệu số lượng; màn kết quả so sánh hai người
- [x] **P11.3** Chat 1-1: SignalR (hoặc hỏi tin mới mỗi ≥ 5 giây theo §2), tải lịch sử theo trang, đánh dấu đã đọc, bong bóng tin nhắn có giờ gửi, gửi lỗi thì có nút thử lại
- [x] **P11.4** Danh sách bạn bè và tìm người chơi (debounce 400ms)

### P12 — Kiểm thử, demo & dọn dẹp
- [ ] **P12.1** Rà toàn app theo checklist của skill, **làm ở cả giao diện sáng và tối**: vùng chạm ≥ 48dp, độ tương phản, chế độ giảm chuyển động, cỡ chữ hệ thống lớn nhất, vùng an toàn (tai thỏ, thanh điều hướng), màn 360dp và màn ngang
- [ ] **P12.2** `flutter analyze` không còn cảnh báo, `flutter test` qua hết
- [ ] **P12.3** Chạy API trên máy cá nhân, kiểm tra nhanh **tuần tự** từng API trên DB somee. (Deploy để sau, khi bạn yêu cầu)
- [ ] **P12.4** Build APK để demo; cập nhật README (bỏ các câu không còn đúng, ví dụ chuyện chạy test)
- [ ] **P12.5** **Xóa `text.txt`**; kiểm tra lại toàn bộ repo không còn chuỗi kết nối hay mật khẩu (`git grep -i "pwd="`)

---

## 4. Thứ tự thực hiện đề xuất
`P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9 → P10 → P11 → P12`

Lý do: bạn ưu tiên UX Rubik nên P2–P4 làm sớm. Engine vuốt xoay (P2) là nền móng cho cả hai tính năng Rubik. Backend (P5–P6) làm trước các game còn lại để game nào làm xong là gửi điểm được ngay.

## 4b. Phân công model (tối ưu token + tốc độ)

| Ai làm | Task | Lý do |
|---|---|---|
| **Opus** (luồng chính) | P0, P1.1–P1.4 (theme, khung app), **P2** (vuốt xoay tầng), P3, P4.3–P4.5, thiết kế AI Caro, review và ghép code | Hình học 3D, kiến trúc, quyết định UX: dễ sai, cần nắm toàn bộ bối cảnh |
| **Sonnet** (agent phụ, chạy nền song song) | **P5 + P6.3 + P8.1** (backend `backend/`: schema SQL, API auth, history, leaderboard), P7 Sudoku, P9 Caro (theo thiết kế của Opus), P10 Xếp hình, P8.2 UI xếp hạng, P11 | Phần việc tách riêng, đặc tả rõ; backend nằm ở thư mục riêng nên chạy song song không đụng code Flutter |
| **Haiku** (agent phụ) | Sửa hàng loạt cỡ chữ / vùng chạm / emoji (P4.2), viết unit test theo đặc tả có sẵn, tải font | Việc rập khuôn |

Quy tắc cho agent phụ:
- **Không commit git.**
- **Không kết nối DB somee.** Chỉ Opus chạy script SQL, chạy một lần và tuần tự.
- **Không sửa file ngoài phạm vi được giao.**
- Xong việc phải chạy `flutter analyze` hoặc `dotnet build`.
- Opus review lại trước khi đánh dấu task là xong.

## 5. Để sau
- Deploy API lên somee: khi nào bạn yêu cầu thì làm.
- Logo và tên chính thức của app: khi có thì thay vào task P1.1c.
