# GameHub – Tổng quan toàn bộ dự án

> Tài liệu giải thích **cơ bản** dự án làm được gì, gồm những phần nào và chúng nối với nhau ra sao.
> Chi tiết từng luồng hoạt động và logic xử lý xem `LUONG_XU_LY_CHI_TIET.md`.

---

## 1. GameHub là gì?

GameHub là **ứng dụng di động (Android, viết bằng Flutter)** gom **4 trò chơi trí tuệ** vào một app, dùng chung một tài khoản:

| Trò chơi | Chơi một mình | Chơi với người khác |
|---|---|---|
| **Sudoku** | Classic 5 độ khó, Học Sudoku (30 màn), Toán Chéo (30 màn) | Sudoku **đồng đội** (2 người cùng giải 1 bàn) |
| **Caro** | Đấu với máy (AI 3 mức), 2 người cùng máy, Cờ sinh tồn | **Caro online** 15×15 (xếp hạng / giao hữu) |
| **Rubik 3D** | Luyện giải trên khối 3D, Quét khối thật bằng camera rồi giải | – |
| **Xếp hình** | Sliding (xếp số trượt), Jigsaw (ghép tranh), PhaseShift | **Đua Xếp số** online |

Ngoài trò chơi, app có:
- **Đối kháng thời gian thực**: tìm trận xếp hạng (tính Elo) hoặc mời bạn giao hữu.
- **Xã hội**: kết bạn, xem bạn đang online, nhắn tin, thách đấu.
- **Bảng xếp hạng**: Kỷ lục (điểm cao nhất chơi một mình) và Đối kháng (rating Elo), theo mùa giải hằng tuần.
- **Hồ sơ**: rating từng game, lịch sử trận, đổi tên, đổi mật khẩu.

**Ý tưởng chính:** các trò giải đố thường tách rời và chơi một mình → GameHub gom chúng lại, cho chơi cùng nhau, và để **server** tính điểm, xếp hạng (chống gian lận).

---

## 2. Công nghệ

| Lớp | Công nghệ | Dùng để |
|---|---|---|
| App di động | **Flutter / Dart 3**, Provider | Giao diện + logic trò chơi |
| Gọi API | `http` + **JWT** | Đăng nhập, lấy / gửi dữ liệu |
| Realtime | **SignalR** (`signalr_netcore` ở app) | Online/offline, tin nhắn, trận đấu trực tiếp |
| Rubik | `cuber` (bảng tra Kociemba), `camera`, `image` | Giải khối, quét màu |
| Lưu trên máy | `shared_preferences` | Phiên đăng nhập, bộ lọc, hàng đợi điểm khi mất mạng |
| Server | **ASP.NET Core (.NET 10)** Web API | REST API + hub SignalR |
| Cơ sở dữ liệu | **SQL Server** + **Entity Framework Core** | 13 bảng |
| Kiểm thử | `flutter_test`, **xUnit** | 225 test app + 126 test backend |
| Triển khai | VPS Linux, `systemd` | Server chạy 24/7, cổng 5214 |

---

## 3. Cấu trúc thư mục

```
DoAn_Moblie/
├── backend/
│   ├── GameHub.Api/            ← server
│   │   ├── Controllers/        ← các API REST (Auth, Users, Friends, History, Leaderboard…)
│   │   ├── Services/           ← logic nghiệp vụ (tính điểm, Elo, trận đấu, hub SignalR…)
│   │   ├── Repositories/       ← truy vấn CSDL
│   │   ├── model/              ← Entity (bảng), DTO (dữ liệu vào/ra), DbContext
│   │   ├── Migrations/         ← lịch sử thay đổi CSDL (EF Core)
│   │   └── Program.cs          ← cấu hình & khởi động server
│   └── GameHub.Tests/          ← test xUnit
├── frontend_new/
│   ├── lib/
│   │   ├── core/               ← dùng chung: mạng, realtime, theme, widget, model
│   │   ├── auth/  shell/  hub/ ← đăng nhập, thanh 5 tab, màn chọn game
│   │   ├── sudoku/ caro/ rubik/ XepHinh/   ← 4 trò chơi
│   │   ├── pvp/                ← đối kháng online
│   │   ├── leaderboard/  profile/  friends/
│   │   └── main.dart
│   ├── test/                   ← test Flutter
│   └── android/                ← cấu hình Android, icon app
└── docs/                       ← tài liệu này
```

---

## 4. Kiến trúc tổng thể

```
┌──────────────── App Flutter ────────────────┐        ┌──────── ASP.NET Core ────────┐       ┌── SQL Server ──┐
│ Màn hình (5 tab)                            │  REST  │ Controllers  (/api/...)      │  EF   │ 13 bảng        │
│   ↓                                         │ + JWT  │   ↓                          │ Core  │ Users, History,│
│ Controller (Provider, ChangeNotifier)       │ ─────► │ Services  (điểm, Elo, …)     │ ────► │ Matches, …     │
│   ↓                       ↓                 │        │   ↓                          │       │                │
│ ApiClient (REST)   RealtimeService (SignalR)│ ◄────► │ Repositories                 │       │                │
│                                             │SignalR │ GameHub + MatchService       │       │                │
│ Logic game chạy trên máy: AI Caro,          │        │ (trận đấu giữ trong bộ nhớ)  │       │                │
│ giải Rubik, sinh đề Sudoku                  │        │                              │       │                │
└─────────────────────────────────────────────┘        └──────────────────────────────┘       └────────────────┘
```

- **REST** cho dữ liệu "bình thường": đăng nhập, lịch sử, bảng xếp hạng, bạn bè, tin nhắn cũ.
- **SignalR** (một kết nối WebSocket giữ mở) cho thứ cần **tức thì**: ai đang online, tin nhắn mới, nước đi trong trận.
- **Logic nặng chạy ngay trên máy** (AI Caro, giải Rubik, sinh đề Sudoku) → không tốn server, chơi được khi mất mạng.
- **Server quyết định** những gì ảnh hưởng xếp hạng: điểm, Elo, kết quả trận.

---

## 5. Ứng dụng: 5 tab

| Tab | Nội dung |
|---|---|
| **Trò chơi** | 4 thẻ game, chọn chế độ và độ khó |
| **Đối kháng** | Tìm trận xếp hạng (Caro, Đua Xếp số) hoặc mời bạn giao hữu |
| **Xếp hạng** | Bảng Kỷ lục / Đối kháng, bục top 3, thanh "vị trí của bạn" |
| **Bạn bè** | Danh sách bạn + trạng thái, lời mời, tin nhắn, thách đấu |
| **Hồ sơ** | Rating từng game, 3 trận gần nhất, đổi tên, đổi mật khẩu, giao diện sáng/tối |

Khách (chưa đăng nhập) vẫn chơi được; điểm chỉ tính tạm trên máy, không lên bảng xếp hạng.

---

## 6. Bốn trò chơi (cơ bản)

### 6.1 Sudoku
- **5 độ khó** theo số ô cho sẵn: Dễ 40 · Trung bình 32 · Khó 26 · Chuyên gia 22 · Ác mộng 17.
- **Sinh đề**: điền 3 khối 3×3 trên đường chéo → điền phần còn lại bằng **quay lui (backtracking)** → xoá bớt ô. Cùng **seed** thì ra cùng đề (dùng cho đồng đội, thách đấu).
- **Học Sudoku** (30 màn mở khoá dần), **Toán Chéo** (30 màn điền số cho phép tính đúng).
- **Đồng đội**: 2 người **chia lượt** (mỗi lượt 1 số), 3 lỗi chung, tối đa 30 phút; thấy ô bạn đang chọn; được ghi chú khi chưa tới lượt.
- Lưu ván, tiến trình, thống kê lên server.

### 6.2 Caro
- **Đấu máy**: AI 3 mức. Mức Khó: khai cuộc chuẩn, **phòng thủ trước** (chặn nước thắng, 4 mở, đòn đôi 4-4 / 4-3 / 3-3, chuỗi VCF) rồi mới tấn công bằng **VCF** và **minimax cắt tỉa alpha-beta** (đào sâu 2–5 tầng trong 1,2 giây). AI chạy trên **Isolate** riêng để UI không giật.
- **2 người cùng máy**, **Cờ sinh tồn** (mỗi bên tối đa 6 quân, quân thứ 7 xoá quân cũ nhất).
- Tối đa 3 gợi ý mỗi ván; ván đang chơi lưu lên server (đổi máy vẫn chơi tiếp).

### 6.3 Rubik 3D
- **Luyện giải**: app xáo khối theo độ khó, người chơi vuốt để xoay lớp; khối 3D tự vẽ bằng `CustomPainter`.
- **Quét & giải**: camera quét 6 mặt → nhận màu (ngưỡng **HSV**) → kiểm tra hợp lệ → giải bằng **Kociemba hai pha** → hướng dẫn từng bước. Bộ giải được cải tiến: tìm thấy lời giải dài *s* vẫn tìm tiếp với giới hạn *s − 1* để ra lời giải ngắn hơn.

### 6.4 Xếp hình
- **Sliding**: xếp số trượt 3×3 / 4×4 / 5×5; đề luôn giải được nhờ kiểm tra **chẵn lẻ số nghịch thế**.
- **Jigsaw**: đổi chỗ mảnh để hoàn chỉnh bức tranh, chọn được ảnh trong máy.
- **PhaseShift** (trò chơi tự thiết kế): thả 7 loại khối nguyên tố, gặp nhau thì **phản ứng** (Điện nổ, Nước dập Lửa, Lửa làm Băng tan, Băng/Lạnh đóng băng Nước, Axit hoà tan Đá), phản ứng nối tiếp tăng **combo**; có engine vật lý cho khối rơi, nước tràn.

---

## 7. Đối kháng thời gian thực

- **Xếp hạng**: vào hàng đợi, server ghép người có rating gần nhất; khoảng ghép nới dần ±100 → ±200 → ±400 → không giới hạn (sau 0/10/20/30 giây). Kết quả đổi **Elo**.
- **Giao hữu**: mời một người bạn đang online, lời mời hết hạn sau 30 giây, không đổi rating.
- Chế độ online: **Caro 15×15**, **Đua Xếp số**, **Sudoku đồng đội**.
- Trong trận: đầu hàng, cầu hoà (tối đa 3 lần), tái đấu (trong 30 giây), chat nhanh, **kết nối lại** (30 giây ân hạn khi rớt mạng).
- Toàn bộ trạng thái trận nằm **trong bộ nhớ server**; chỉ khi trận kết thúc mới ghi DB trong **một transaction**.

---

## 8. Xã hội

- **Bạn bè**: tìm người chơi, gửi / nhận / huỷ lời mời; thấy bạn **online / đang trong trận / offline** theo thời gian thực.
- **Nhắn tin**: chỉ giữa bạn bè, tin tới tức thì, có đã đọc / chưa đọc.
- **Thách đấu bất đồng bộ**: hai người chơi **cùng một đề** (seed = mã thách đấu) vào lúc nào tiện; server so điểm rồi thời gian để chọn người thắng; lời thách quá 7 ngày tự hết hạn.

---

## 9. Tính điểm, Elo, xếp hạng

**Điểm một ván** (server tính):
```
điểm = round( base × hệ số thời gian × 0.92^lỗi × 0.85^gợi ý )
base = 1000 × độ khó        hệ số thời gian = clamp(par / thời gian, 0.25, 1.5)
```
Caro dùng **số nước** thay thời gian; hoà Caro được 30%; thua / bỏ cuộc = 0.

**Elo** (trận xếp hạng): khởi điểm 1000, K = 40 trong 10 trận đầu rồi 24. Bậc: Đồng < 1100 · Bạc < 1250 · Vàng < 1400 · Bạch kim < 1600 · Kim cương ≥ 1600.

**Bảng xếp hạng**: Kỷ lục (điểm cao nhất mỗi người, chọn theo độ khó) và Đối kháng (rating). Lọc **Tuần này / Mọi lúc**, **Toàn server / Bạn bè**. Mùa giải = 1 tuần, bắt đầu 0 giờ thứ Hai (giờ VN). Đồng hạng xếp kiểu **1, 2, 2, 4**.

---

## 10. Cơ sở dữ liệu (13 bảng)

| Nhóm | Bảng |
|---|---|
| Tài khoản & xã hội | `Users`, `Friendships`, `Messages`, `Challenges` |
| Trò chơi & kết quả | `Games`, `GameLevels`, `History`, `Matches`, `PlayerRatings` |
| Tiến trình & ván lưu | `SudokuProgresses`, `SudokuSavedGames`, `SudokuDifficultyStats`, `CaroSavedGames` |

Server **tự chạy migration** khi khởi động, nên CSDL luôn khớp với code.

---

## 11. Bảo mật

- Mật khẩu băm bằng **BCrypt**; đăng nhập trả **JWT** (hạn 7 ngày) dùng cho cả REST lẫn SignalR.
- **Giới hạn tần suất**: đăng nhập 10/phút/IP, tin nhắn 20/phút, thách đấu 10/giờ, đổi mật khẩu 5/15 phút.
- **Server quyết định** điểm, Elo, kết quả trận; kiểm tra mọi nước đi online.
- Lỗi trả về theo chuẩn **ProblemDetails (RFC 7807)**, thông điệp tiếng Việt.
- Khoá bí mật (chuỗi kết nối, khoá JWT) đọc từ `.env` / biến môi trường, không viết cứng trong mã nguồn.

---

## 12. Kiểm thử

- **Flutter: 225 test** – logic game (AI Caro, Rubik, Sudoku, PhaseShift), tính điểm, realtime, các màn hình chính.
- **Backend: 126 test (xUnit)** – tính điểm, xếp hạng, Elo, trận đấu (dùng đồng hồ giả), thách đấu, Sudoku.

---

## 13. Triển khai

- **Server**: đóng gói `dotnet publish` (tự chứa runtime) → chép lên **VPS Linux** → chạy như service `systemd` tên `gamehub-api`, cổng 5214. Trước mỗi lần cập nhật đều sao lưu bản cũ.
- **CSDL**: SQL Server. Server tự áp migration khi khởi động.
- **App**: tên **GameHub**, logo "Bốn ô" (4 ô màu đại diện 4 game), adaptive icon cho Android 8+.

---

## 14. Quy trình phát triển

- Phát triển trên **nhánh tính năng**, gộp vào `main` qua **Pull Request**.
- Trước khi gộp: chạy toàn bộ test; cập nhật nhánh theo `main` mới nhất.

---

## 15. Thuật ngữ nhanh

| Thuật ngữ | Nghĩa ngắn |
|---|---|
| **REST API** | Gọi server qua HTTP (GET/POST/PUT/DELETE), mỗi lần hỏi – đáp một lần |
| **SignalR / WebSocket** | Kết nối giữ mở, server **chủ động đẩy** dữ liệu xuống app |
| **JWT** | "Vé" đã ký, app gửi kèm mỗi yêu cầu để chứng minh đã đăng nhập |
| **EF Core / Migration** | Thư viện map bảng ↔ class C#; migration = các bước thay đổi cấu trúc DB |
| **Elo** | Hệ thống rating: thắng người mạnh được cộng nhiều, thua người yếu bị trừ nhiều |
| **Seed** | Số khởi tạo cho bộ sinh ngẫu nhiên: cùng seed → cùng đề |
| **Isolate** | Luồng chạy riêng của Dart, để tính toán nặng không làm giật giao diện |
| **Minimax / alpha-beta** | Tìm kiếm cây nước đi giả định đối thủ đi tốt nhất; alpha-beta cắt bớt nhánh thừa |
| **Kociemba** | Thuật toán giải Rubik hai pha, cho lời giải ngắn rất nhanh |
