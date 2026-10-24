# TASKS V2: nâng cấp thành app game chuyên nghiệp

> Giai đoạn 2, nối tiếp `TASKS.md`. Trọng tâm: **Xếp hạng**, **Bạn bè**, **Đấu 1-1 trực tiếp (PvP)**.
> Bạn cho phép tự thiết kế lại logic. Các quyết định dưới đây lấy theo cách làm phổ biến của các app game hiện nay.
> Quy tắc giữ nguyên: không bắn nhiều request cùng lúc lên DB somee; chỉ commit khi bạn yêu cầu; UI theo `ui-ux-pro-max`, có cả giao diện sáng và tối.

---

## 1. Rà soát hiện trạng: các lỗi cụ thể tìm được

### Xếp hạng
| # | Vấn đề | Hậu quả |
|---|---|---|
| L1 | Công thức điểm trừ **1 điểm/giây** cho mọi game | Sudoku Khó (20–40 phút) hay Rubik Khó luôn chạm **điểm sàn**, nên nhiều người cùng điểm và bảng xếp hạng không còn ý nghĩa |
| L2 | Caro chấm điểm chủ yếu theo thời gian | Thắng máy mức Dễ thật nhanh được điểm cao, không phản ánh trình độ |
| L3 | Danh sách đánh hạng 1,2,3… liên tục, còn "Hạng của bạn" tính theo số người có điểm cao hơn | Hai người bằng điểm thì danh sách và dòng "Hạng của bạn" **lệch nhau** |
| L4 | Mỗi game tách 3 bảng theo độ khó, mặc định mở bảng "Vừa" | Bảng nào cũng thưa, thường hiện "Chưa có ai trên bảng". Chơi mức Dễ xong vào xem không thấy tên mình |
| L5 | "Tuần này" là 7 ngày trượt | Không có mốc reset rõ ràng như mùa giải / tuần của game thật |
| L6 | Chỉ có bảng kỷ lục chơi đơn | Không có xếp hạng đối kháng (Elo/rank), không có bảng **xếp hạng bạn bè** |

### Bạn bè
| # | Vấn đề | Hậu quả |
|---|---|---|
| F1 | Không có khái niệm "bạn bè": ai cũng tìm, nhắn tin và thách đấu được bất kỳ ai | Không có danh sách bạn, không có lời mời kết bạn, dễ bị làm phiền |
| F2 | Không biết ai đang online | Không thể rủ nhau chơi ngay |
| F3 | Chat và huy hiệu dựa trên hỏi lại server định kỳ (5–15 giây) | Tin nhắn đến chậm, tốn request |
| F4 | Chỉ có thách đấu **không đồng thời** (mỗi người tự chơi rồi so điểm) | **Không đánh trực tiếp với nhau được.** Caro chỉ đấu với máy |

---

## 2. Thiết kế mới (các quyết định đã chốt)

### 2.1 Điểm kỷ lục (chơi đơn)
Điểm dựa trên **thời gian chuẩn (par)** của từng game và độ khó, không trừ cố định theo giây nữa:
```
hệ số thời gian = clamp(par / thời gian thực, 0.25, 1.5)      // nhanh hơn chuẩn thì được thưởng
hệ số lỗi       = 0.92 ^ số lỗi                              // mỗi lỗi giảm 8%
điểm            = round(base × hệ số thời gian × hệ số lỗi)  // base = 1000 / 2000 / 3000
```
| Game | Par Dễ | Par Vừa | Par Khó |
|---|---|---|---|
| Sudoku | 6 phút | 12 phút | 25 phút |
| Xếp hình | 60 giây | 4 phút | 10 phút |
| Rubik (luyện giải) | 90 giây | 4 phút | 10 phút |
| Caro (thắng máy) | điểm theo **số nước**: par = 20 / 30 / 45 nước | | |

- Thua hoặc bỏ cuộc = 0 điểm. Caro hòa = 30% điểm.
- Server là nơi tính điểm chuẩn; client chỉ tính để hiển thị tạm, dùng cùng công thức.

### 2.2 Bảng xếp hạng
- Mỗi game có 2 chế độ xem:
  - **Đối kháng**: xếp theo rating Elo.
  - **Kỷ lục**: xếp theo điểm cao nhất. Mặc định gộp **"Tất cả độ khó"** (điểm đã nhân sẵn hệ số độ khó), có thể lọc riêng Dễ/Vừa/Khó.
- Phạm vi: **Toàn server** hoặc **Bạn bè**. Thời gian: **Mùa này** hoặc **Mọi thời điểm**. "Mùa" = tuần lịch, reset 00:00 thứ Hai (giờ VN), hiện đếm ngược "Còn 3 ngày 4 giờ".
- Đánh hạng **kiểu thi đấu** (1, 2, 2, 4): bằng điểm thì xét thời gian ngắn hơn, rồi tới người đạt trước. Danh sách và dòng "Hạng của bạn" dùng chung một cách tính.
- Chạm vào một người chơi → mở **thẻ hồ sơ**: rank, rating, thống kê, các nút Kết bạn / Thách đấu / Nhắn tin.

### 2.3 Rating Elo và bậc rank (đối kháng)
- Mỗi người có một rating riêng cho từng game, khởi điểm 1000.
- K = 40 trong 10 trận đầu (giai đoạn xếp hạng), sau đó K = 24.
- Thắng/thua/hòa tính theo công thức Elo chuẩn.
- Bậc rank: **Đồng** < 1100 · **Bạc** < 1250 · **Vàng** < 1400 · **Bạch kim** < 1600 · **Kim cương** ≥ 1600. Có icon và tên bậc (không chỉ dựa vào màu).
- Chỉ trận **Xếp hạng** (tìm trận nhanh) mới cộng/trừ rating. Trận **Giao hữu** (mời bạn) không ảnh hưởng.

### 2.4 Bạn bè
- Gửi lời mời → đối phương Chấp nhận / Từ chối. Có Hủy kết bạn.
- Danh sách bạn có **chấm online**, sắp xếp: đang online, đang trong trận, offline (kèm "x phút trước").
- **Chỉ nhắn tin và mời đấu giao hữu với bạn bè** (chống làm phiền). Tìm trận nhanh thì gặp người lạ như bình thường.
- Thông báo thời gian thực qua kết nối realtime: lời mời kết bạn, lời mời đấu, tin nhắn mới.

### 2.5 Đấu 1-1 trực tiếp (PvP)
**Truyền dữ liệu:** dùng **SignalR** (`/hubs/game`). Client là `signalr_netcore`, tự dùng WebSocket và tự lùi về long-polling nếu đường mạng (vd: Conveyor) không hỗ trợ.
- **Trạng thái trận nằm trong bộ nhớ server.** Chỉ ghi DB **một lần khi kết thúc trận** (bảng `Matches` + `History` + rating), nên không tạo áp lực lên DB somee.

**Hai kiểu trận:**
| Game | Kiểu | Luật |
|---|---|---|
| **Caro** | **Đấu lượt trực tiếp** | Server là trọng tài: kiểm tra nước đi hợp lệ, xác định thắng 5 quân. Mỗi lượt **30 giây**, hết giờ thì thua. Người đi trước chọn ngẫu nhiên. Có xin hòa và đầu hàng |
| **Sudoku / Xếp hình / Rubik** | **Đua giải cùng đề** | Hai người nhận **cùng một đề** (seed từ server). Thấy **thanh tiến độ của đối thủ** theo thời gian thực. **Ai giải xong trước thì thắng**. Giới hạn 15 phút, hết giờ thì so tiến độ |

**Vào trận:**
- **Tìm trận nhanh (Xếp hạng):** vào hàng đợi theo game + độ khó, ghép người có rating gần nhau. Khoảng rating cho phép nới dần: ±100 → ±200 → ±400 → không giới hạn sau 30 giây. Có nút Hủy tìm.
- **Mời bạn (Giao hữu):** lời mời có hạn **30 giây**. Bên kia thấy thông báo nổi để Chấp nhận / Từ chối.

**Trong trận:**
- Thanh trên cùng: avatar, tên, rank của 2 người, chỉ báo lượt hoặc tiến độ, đồng hồ.
- Tin nhắn nhanh dựng sẵn ("Chào bạn!", "Hay lắm!", "Chơi lại nhé?"), không gõ chữ tự do để tránh nội dung xấu.
- **Mất kết nối:** có 30 giây để kết nối lại (hiện "Đối thủ đang kết nối lại…"). Quá hạn thì xử thua.
- **Kết thúc:** màn kết quả hiện thắng/thua, **rating +/-** có hiệu ứng đếm, **Tái đấu** (cần cả hai đồng ý), Về sảnh.

**Chống gian lận:**
- Caro do server kiểm tra hoàn toàn.
- Trò đua: server kiểm tra thời gian tối thiểu hợp lý và tiến độ phải tăng dần. Đây là mức giới hạn chấp nhận được cho đồ án, sẽ ghi rõ trong báo cáo.

### 2.6 Điều hướng mới (5 mục, đúng giới hạn tối đa)
**Trò chơi · Đối kháng · Xếp hạng · Bạn bè · Hồ sơ**
- **Đối kháng:** chọn game và độ khó → Tìm trận nhanh; lời mời đang chờ; lịch sử trận; rating và rank theo từng game.
- **Bạn bè:** danh sách bạn (có online), lời mời kết bạn, tìm người chơi, tin nhắn, thách đấu không đồng thời (giữ lại cho lúc không online cùng nhau).
- **Hồ sơ:** thẻ người chơi (avatar, rank cao nhất) và **thống kê** theo từng game (số trận, tỉ lệ thắng, kỷ lục, rating).

---

## 3. Hợp đồng API (để backend và app làm song song)

### Bảng mới: `db/migrations/003_pvp_friends.sql`
- `Users.last_seen_at`
- `Friendships(friendship_id, requester_id, addressee_id, status PENDING|ACCEPTED|DECLINED, created_at, responded_at)`, mỗi cặp người chỉ có một dòng
- `PlayerRatings(user_id, game_id, rating, games, wins, losses, draws, peak_rating, updated_at)`
- `Matches(match_id, game_id, difficulty, mode RANKED|FRIENDLY, kind TURN|RACE, player1_id, player2_id, winner_id NULL, end_reason, seed, started_at, ended_at, p1_rating_before/after, p2_rating_before/after)`
- `History.match_id` (NULL, khóa ngoại tới Matches)
- Mọi khóa ngoại `NO ACTION`, script chạy lại nhiều lần không lỗi, có `SET QUOTED_IDENTIFIER ON`

### REST (`/api`, đều yêu cầu đăng nhập trừ khi ghi chú khác)
| Method | Đường dẫn | Mô tả |
|---|---|---|
| GET | `/friends` | Danh sách bạn + trạng thái online / trong trận + last_seen |
| GET | `/friends/requests` | Lời mời kết bạn đến và đi |
| POST | `/friends/requests` `{userId}` | Gửi lời mời. Nếu bên kia đã mời mình thì tự thành bạn |
| POST | `/friends/requests/{id}/accept`, `/decline` | Chấp nhận / từ chối lời mời |
| DELETE | `/friends/{userId}` | Hủy kết bạn |
| GET | `/users/{id}/profile` | Hồ sơ công khai: thống kê, rating theo game, quan hệ bạn bè với mình |
| GET | `/leaderboard?gameCode&board=ranked\|record&difficulty?&scope=global\|friends&period=season\|all` | Top 50, đánh hạng kiểu thi đấu (không cần đăng nhập, trừ khi `scope=friends`) |
| GET | `/leaderboard/me?...` | Hạng của mình trên đúng bảng đó |
| GET | `/leaderboard/season` | Thời điểm bắt đầu/kết thúc tuần hiện tại |
| GET | `/matches?page` | Lịch sử trận của mình |
| GET | `/ratings/me` | Rating và rank của mình ở cả 4 game |

### SignalR hub `/hubs/game` (xác thực JWT qua `access_token` trên query)
**Client gọi lên server:**
- `QueueJoin(gameCode, difficulty)`, `QueueLeave()`
- `Invite(friendId, gameCode, difficulty)`, `RespondInvite(inviteId, accept)`
- `CaroMove(matchId, row, col)`
- `RaceProgress(matchId, percent)`, `RaceFinish(matchId, timeMs, mistakes)`
- `Resign(matchId)`, `OfferDraw(matchId)`, `RespondDraw(matchId, accept)`
- `Rematch(matchId)`, `QuickChat(matchId, code)`
- `Rejoin(matchId)`

**Server đẩy xuống client:**
- `Presence(userId, status)`, `FriendRequest(...)`, `FriendAccepted(...)`, `MessageReceived(...)`
- `InviteReceived(invite)`, `InviteResult(...)`, `QueueStatus(searching, waitedSec, range)`
- `MatchStarted(match)`, `MatchState(match)`, `OpponentProgress(...)`, `QuickChat(...)`
- `OpponentConnection(connected, graceSec)`, `MatchEnded(result: winner, reason, ratingChanges)`

**Giới hạn tần suất:** `RaceProgress` tối đa 4 lần/giây; tin nhắn nhanh 1 lần/2 giây.

---

## 4. Danh sách task

### Q0: Chuẩn bị
- [x] **Q0.1** Viết migration `003` và chạy **một lần** lên somee (`-f 65001 -I`)
- [x] **Q0.2** Thêm package `signalr_netcore`

### Q1: Backend (một agent Sonnet, mình review)
- [x] **Q1.1** `ScoreCalculator` v2 (công thức par §2.1) + unit test. Sửa `GameRecord.localScore` / `computeScore` phía app cho khớp
- [x] **Q1.2** Leaderboard v2: chế độ ranked/record, gộp tất cả độ khó, phạm vi bạn bè, mùa theo tuần lịch giờ VN, đánh hạng kiểu thi đấu với luật phân thắng khi bằng điểm, `/leaderboard/season` + test
- [x] **Q1.3** API bạn bè + hồ sơ công khai + thống kê. Chat và thách đấu không đồng thời chỉ giữa bạn bè
- [x] **Q1.4** `GameHub` (SignalR, JWT): theo dõi online (đa thiết bị), cập nhật `last_seen` (giới hạn mỗi 60 giây), đẩy thông báo bạn bè và tin nhắn
- [x] **Q1.5** `MatchService` (singleton, có khóa để an toàn khi nhiều luồng): hàng đợi ghép trận nới khoảng rating dần, lời mời 30 giây, vòng đời trận, đồng hồ (lượt 30 giây, đua 15 phút, kết nối lại 30 giây), tái đấu
- [x] **Q1.6** Trọng tài Caro (kiểm tra nước, thắng 5 quân, hòa khi đầy bàn) và trọng tài trò đua (tiến độ tăng dần, thời gian tối thiểu)
- [x] **Q1.7** Khi kết thúc trận: ghi **một transaction** gồm `Matches` + 2 dòng `History` + `PlayerRatings` (Elo), rồi đẩy `MatchEnded`
- [x] **Q1.8** Test: Elo, ghép trận, trọng tài Caro, hết giờ, mất kết nối/kết nối lại, chống gửi trùng (dùng đồng hồ giả, không cần DB thật)
- AC: `dotnet test` qua (108 test). *Đã test đầu-cuối trên DB thật bằng 2 client SignalR: mời đấu → Caro thắng; tìm trận nhanh → đua Sudoku → đầu hàng, rating 1000→1020/980; chặn đi sai lượt và chặn về đích gian lận.*

### Q2: App, phần nền (agent Sonnet, làm song song Q1 dựa trên hợp đồng §3)
- [ ] **Q2.1** `RealtimeService`: kết nối hub khi đăng nhập, tự kết nối lại (có backoff), luồng sự kiện, ngắt khi đăng xuất hoặc app chạy nền lâu
- [ ] **Q2.2** Thông báo nổi trong app (lời mời đấu có nút Chấp nhận / Từ chối và đồng hồ 30 giây; lời mời kết bạn; tin nhắn mới) + rung nhẹ
- [ ] **Q2.3** Chat chuyển sang nhận tin qua realtime; chỉ hỏi server khi vừa kết nối lại
- [ ] **Q2.4** Mô hình rank và tier (icon + tên + màu), widget `RankBadge` và `PlayerCard`

### Q3: App, Xếp hạng và Bạn bè và Hồ sơ (agent Sonnet)
- [ ] **Q3.1** Màn Xếp hạng v2 theo §2.2 (Đối kháng/Kỷ lục, Toàn server/Bạn bè, Mùa này/Mọi thời điểm, đếm ngược mùa, nhớ lựa chọn gần nhất, chạm người chơi để mở thẻ hồ sơ)
- [ ] **Q3.2** Màn Bạn bè v2: danh sách bạn có online, lời mời kết bạn (badge), tìm người chơi, nút Mời đấu / Nhắn tin, vuốt hoặc menu để hủy kết bạn (có xác nhận)
- [ ] **Q3.3** Hồ sơ v2: thống kê theo game, rank cao nhất, lịch sử trận
- [ ] **Q3.4** Thanh điều hướng 5 mục (§2.6)

### Q4: App, Đối kháng (Opus làm phần Caro online và luồng trận; Sonnet làm phần đua giải)
- [ ] **Q4.1** Sảnh Đối kháng: chọn game và độ khó, nút Tìm trận nhanh (hiệu ứng đang tìm, thời gian chờ, khoảng rating đang nới, nút Hủy), lời mời đang chờ, lịch sử trận, rating từng game
- [ ] **Q4.2** **Caro online**: dùng lại bàn cờ `CaroBoardView`; chỉ báo lượt, đồng hồ 30 giây/lượt (đỏ dần khi gần hết), xem trước nước đi rồi xác nhận, xin hòa, đầu hàng, tin nhắn nhanh, kết nối lại
- [ ] **Q4.3** **Đua giải** cho Sudoku / Xếp hình / Rubik: dùng lại controller của từng game với seed từ server, thanh tiến độ của mình và đối thủ, thông báo "Đối thủ đã giải xong!"
- [ ] **Q4.4** Màn kết quả trận: thắng/thua/hòa, rating +/- có hiệu ứng đếm (tôn trọng chế độ giảm chuyển động), Tái đấu, Về sảnh
- [ ] **Q4.5** Xử lý biên: app chạy nền giữa trận (cảnh báo), mất mạng (banner đang kết nối lại), đối thủ thoát (thắng do đối thủ bỏ trận), bấm Back giữa trận (xác nhận đầu hàng)

### Q5: Kiểm thử và hoàn thiện
- [ ] **Q5.1** Test đầu-cuối thật: 2 tài khoản trên **điện thoại + máy ảo/Windows** qua Conveyor: kết bạn, mời đấu Caro, đánh hết ván, rating thay đổi, bảng xếp hạng cập nhật
- [ ] **Q5.2** Rà UI bằng ảnh chụp cả giao diện sáng và tối cho mọi màn mới; `flutter analyze` sạch; toàn bộ test qua
- [ ] **Q5.3** Cập nhật README và sơ đồ kiến trúc (SignalR, Elo); xóa dữ liệu thử trên DB

---

## 5. Phân công và thứ tự
1. **Mình (Opus):** Q0 → chốt hợp đồng → review Q1 → Q4.2 + luồng trận Q4.4/Q4.5 → Q5
2. **Agent Sonnet song song:** Q1 (backend) ‖ Q2 + Q3 (app, test bằng dữ liệu giả) → sau đó Q4.1 + Q4.3
3. Mỗi phần xong đều qua `analyze` + test + ảnh chụp, và mình review trước khi đánh dấu `[x]`

## 6. Rủi ro và cách xử lý
- **Conveyor bản miễn phí** có thể chặn WebSocket hoặc làm chậm → SignalR tự lùi về long-polling. Trận vẫn chơi được, chỉ trễ hơn khoảng 0,5–1 giây.
- **Server khởi động lại giữa trận** thì mất trận đang chơi (trạng thái nằm trong bộ nhớ). Chấp nhận được với quy mô đồ án; app báo "Trận bị hủy do máy chủ khởi động lại", không trừ rating.
- **Ít người online** khiến tìm trận nhanh khó ghép → sau 60 giây đề xuất "Mời bạn bè" hoặc "Đấu với máy".
