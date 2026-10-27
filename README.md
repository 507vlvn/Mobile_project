# GameHub

**GameHub** là ứng dụng di động (Flutter) gom **4 trò chơi trí tuệ** – Sudoku, Caro, Rubik 3D, Xếp hình – vào một app dùng chung tài khoản, kèm **đối kháng thời gian thực**, **bạn bè – nhắn tin – thách đấu** và **bảng xếp hạng Elo theo mùa**. Server ASP.NET Core chịu trách nhiệm tính điểm, xếp hạng và điều phối trận đấu.

---

## Tính năng

### Trò chơi
| Trò chơi | Chơi một mình | Chơi với người khác |
|---|---|---|
| **Sudoku** | Classic 5 độ khó (Dễ → Ác mộng), Học Sudoku 30 màn, Toán Chéo 30 màn | Sudoku đồng đội: 2 người chia lượt giải chung một bàn |
| **Caro** | Đấu máy (AI 3 mức), 2 người cùng máy, Cờ sinh tồn (tối đa 6 quân mỗi bên) | Caro online 15×15 – xếp hạng hoặc giao hữu |
| **Rubik 3D** | Luyện giải trên khối 3D (vuốt để xoay tầng), quét khối thật bằng camera rồi hướng dẫn giải từng bước | – |
| **Xếp hình** | Sliding (xếp số trượt), Jigsaw (ghép tranh, dùng được ảnh trong máy), PhaseShift (khối nguyên tố, phản ứng dây chuyền) | Đua Xếp số online |

### Nền tảng
- **Đối kháng realtime** qua SignalR: hàng đợi ghép theo rating, mời bạn giao hữu, đầu hàng / cầu hoà / tái đấu / chat nhanh, tự kết nối lại khi rớt mạng (30 giây ân hạn).
- **Xếp hạng**: bảng Kỷ lục (điểm chơi đơn, theo độ khó) và bảng Đối kháng (Elo), lọc tuần này / mọi lúc, toàn server / bạn bè; top 3 dạng bục, thanh "vị trí của bạn".
- **Xã hội**: kết bạn, trạng thái online / đang trong trận / offline, nhắn tin, thách đấu bất đồng bộ (cùng một đề).
- **Hồ sơ**: rating và bậc từng game, lịch sử trận (tải dần khi cuộn), đổi tên, đổi mật khẩu, giao diện sáng / tối.
- **Chơi khi mất mạng**: điểm được xếp hàng đợi và tự gửi lại khi có mạng; khách vẫn chơi được (điểm tính tại máy).

### Tính điểm
```
điểm = round( 1000 × độ khó × clamp(par / thời gian, 0.25, 1.5) × 0.92^lỗi × 0.85^gợi ý )
```
Caro tính theo số nước thay cho thời gian; hoà Caro được 30%; thua / bỏ cuộc 0 điểm. Điểm luôn do **server** tính.

**Elo**: khởi điểm 1000; K = 40 trong 10 trận xếp hạng đầu, sau đó 24. Bậc: Đồng < 1100 · Bạc < 1250 · Vàng < 1400 · Bạch kim < 1600 · Kim cương ≥ 1600. Mùa giải = 1 tuần, bắt đầu 0 giờ thứ Hai (UTC+7).

---

## Công nghệ

| Thành phần | Công nghệ |
|---|---|
| Ứng dụng di động | Flutter, Dart 3, Provider, `http`, `signalr_netcore`, `shared_preferences`, `camera`, `image`, `cuber` |
| Server | ASP.NET Core Web API (.NET 10), SignalR, JWT, Rate limiting, Swagger |
| Cơ sở dữ liệu | SQL Server, Entity Framework Core (migration) |
| Kiểm thử | `flutter_test`, xUnit |

---

## Kiến trúc

```
┌──────────── App Flutter ────────────┐  REST + JWT   ┌──────── ASP.NET Core ────────┐  EF Core  ┌─────────────┐
│ Màn hình → Controller (Provider)    │ ────────────► │ Controllers → Services        │ ────────► │ SQL Server  │
│ ApiClient · RealtimeService         │ ◄───────────► │ → Repositories                │           │ (13 bảng)   │
│ AI Caro, giải Rubik, sinh đề Sudoku │   SignalR     │ GameHub + MatchService        │           │             │
│ chạy ngay trên máy                  │               │ (trạng thái trận trong bộ nhớ)│           │             │
└─────────────────────────────────────┘               └───────────────────────────────┘           └─────────────┘
```
- **REST** cho dữ liệu thông thường; **SignalR** (`/hubs/game`) cho trạng thái online, tin nhắn và trận đấu.
- Logic nặng (AI Caro trên Isolate, bộ giải Rubik Kociemba, sinh đề Sudoku) chạy trên thiết bị.
- Trận đấu giữ trong bộ nhớ server, kết quả ghi xuống DB trong **một transaction** khi trận kết thúc.

---

## Cấu trúc thư mục

```
.
├── backend/
│   ├── GameHub.Api/          # Web API + hub SignalR
│   │   ├── Controllers/      # REST API
│   │   ├── Services/         # Nghiệp vụ: điểm, Elo, xếp hạng, trận đấu, presence…
│   │   ├── Repositories/     # Truy cập dữ liệu
│   │   ├── model/            # Entity, DTO, DbContext
│   │   ├── Migrations/       # EF Core migration
│   │   └── Program.cs
│   ├── GameHub.Tests/        # Test xUnit
│   └── README.md             # Danh sách API, hợp đồng SignalR, công thức
├── frontend_new/
│   ├── lib/
│   │   ├── core/             # Mạng, realtime, theme, widget dùng chung
│   │   ├── auth/ shell/ hub/ # Đăng nhập, thanh 5 tab, màn chọn game
│   │   ├── sudoku/ caro/ rubik/ XepHinh/
│   │   ├── pvp/              # Đối kháng online
│   │   ├── leaderboard/ profile/ friends/
│   │   └── main.dart
│   ├── test/
│   └── android/
└── docs/                     # Tài liệu tổng quan và luồng xử lý
```

---

## Cài đặt và chạy

### Yêu cầu
- **.NET 10 SDK**
- **SQL Server** (máy cục bộ hoặc dịch vụ host)
- **Flutter SDK** (Dart ≥ 3.13) và Android SDK / máy ảo Android

### 1. Backend
```bash
cd backend/GameHub.Api
cp .env.example .env        # rồi điền chuỗi kết nối và Jwt__Key (≥ 32 ký tự)
dotnet run                  # http://localhost:5214 — Swagger: /swagger
```
- `.env` được nạp thành biến môi trường khi khởi động; có thể dùng `appsettings.Development.json` thay thế. Biến môi trường thật luôn được ưu tiên.
- Server **tự chạy migration** khi khởi động, tạo đủ các bảng.

**Dữ liệu danh mục game** (chỉ cần với một DB hoàn toàn mới): server đọc danh sách game và các mức độ khó từ bảng `Games` / `GameLevels`.
```sql
INSERT INTO Games (game_code, game_name) VALUES
  ('RUBIK', N'Rubik 3x3'), ('SUDOKU', N'Sudoku'), ('PUZZLE', N'Xếp hình'), ('CARO', N'Caro');

INSERT INTO GameLevels (game_id, difficulty, difficulty_name)
SELECT g.game_id, v.d, v.name
FROM Games g
CROSS JOIN (VALUES (1, N'Dễ'), (2, N'Vừa'), (3, N'Khó'), (4, N'Chuyên gia'), (5, N'Ác mộng')) AS v(d, name)
WHERE v.d <= CASE g.game_code WHEN 'SUDOKU' THEN 5 ELSE 3 END
  AND NOT EXISTS (SELECT 1 FROM GameLevels l WHERE l.game_id = g.game_id AND l.difficulty = v.d);
```
> Khi chạy script bằng `sqlcmd`, thêm `-f 65001` (đọc UTF-8 cho tiếng Việt) và `-I` (bật `QUOTED_IDENTIFIER`, cần cho các chỉ mục có lọc).

### 2. Ứng dụng Flutter
```bash
cd frontend_new
# tạo file .env (không commit):
#   API_BASE_URL=http://<địa-chỉ-server>:5214/api
flutter pub get
flutter run --dart-define-from-file=.env
```
- Địa chỉ server chỉ lấy từ `.env` lúc build; thiếu file này app báo "Chưa cấu hình địa chỉ máy chủ".
- Máy ảo Android gọi server trên máy tính qua `http://10.0.2.2:5214/api`.
- Đường dẫn hub SignalR tự suy ra: `…/api` → `…/hubs/game`.

### 3. Chạy test
```bash
cd backend && dotnet test          # test backend
cd frontend_new && flutter test    # test ứng dụng
```

---

## API

Tiền tố `/api`. Xác thực bằng header `Authorization: Bearer <token>` (SignalR dùng query `access_token`). Lỗi trả về dạng **ProblemDetails** (RFC 7807) với thông điệp tiếng Việt.

| Nhóm | Endpoint chính |
|---|---|
| Tài khoản | `POST /auth/register`, `POST /auth/login`, `GET/PUT /users/me`, `PUT /users/me/password`, `GET /users/search` |
| Trò chơi & điểm | `GET /games`, `POST /history`, `GET /history/me` |
| Xếp hạng | `GET /leaderboard`, `GET /leaderboard/me`, `GET /leaderboard/season`, `GET /ratings/me`, `GET /matches` |
| Xã hội | `/friends`, `/friends/requests`, `/messages/...`, `/challenges`, `GET /social/summary` |
| Lưu tiến trình | `/sudoku/progress`, `/sudoku/save-game`, `/sudoku/stats`, `/caro/save-game` |

Danh sách đầy đủ, tham số và hợp đồng sự kiện SignalR: xem [`backend/README.md`](backend/README.md).

**Giới hạn tần suất**: đăng nhập / đăng ký 10/phút/IP · tin nhắn 20/phút · thách đấu 10/giờ · đổi mật khẩu 5/15 phút.

---

## Triển khai

Server được đóng gói **tự chứa runtime** và chạy như một service `systemd` trên Linux:
```bash
dotnet publish backend/GameHub.Api -c Release -r linux-x64 --self-contained true -o publish
# chép thư mục publish lên máy chủ (không kèm appsettings.Development.json / .env),
# đặt cấu hình bí mật trong appsettings.Production.json hoặc biến môi trường,
# rồi khởi động lại service; migration mới tự chạy khi server khởi động.
```
Gợi ý cấu hình service: chạy bằng user riêng, `ASPNETCORE_ENVIRONMENT=Production`, `ASPNETCORE_URLS=http://0.0.0.0:5214`, giới hạn bộ nhớ; đặt reverse proxy HTTPS phía trước khi đưa ra môi trường thật.

---

## Tài liệu

| Tài liệu | Nội dung |
|---|---|
| [`docs/TONG_QUAN_DU_AN.md`](docs/TONG_QUAN_DU_AN.md) | Tổng quan chức năng, kiến trúc, dữ liệu, bảo mật |
| [`docs/LUONG_XU_LY_CHI_TIET.md`](docs/LUONG_XU_LY_CHI_TIET.md) | Từng luồng hoạt động và logic xử lý, kèm sơ đồ |
| [`backend/README.md`](backend/README.md) | Chi tiết API, SignalR, công thức điểm và Elo |
