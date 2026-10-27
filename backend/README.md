# GameHub API

ASP.NET Core Web API (.NET 10) + EF Core SQL Server + JWT.

## Chạy thử

1. Chạy `db/schema.sql` trên SQL Server (tạo bảng, view, dữ liệu mẫu). Script chạy lại nhiều lần không lỗi.
   **Bắt buộc dùng `-f 65001`** để sqlcmd đọc file theo UTF-8, nếu không chữ tiếng Việt sẽ bị lỗi mã:
   ```
   sqlcmd -S <server> -d doan_mobile -U <user> -P <password> -C -f 65001 -i db/schema.sql
   ```
   `db/reset_dev.sql` xoá toàn bộ bảng để tạo lại từ đầu — **chỉ dùng khi phát triển, mất hết dữ liệu**.
2. Mở `GameHub.Api/appsettings.Development.json` (đã gitignore), thay `YOUR_SERVER`, `YOUR_USER`, `YOUR_PASSWORD` trong `ConnectionStrings:DefaultConnection`.
   Nên đổi luôn `Jwt:Key` (>= 32 ký tự) trong file này khi deploy thật.
3. Chạy:
   ```
   cd backend/GameHub.Api
   dotnet run
   ```
4. Mở Swagger: http://localhost:5214/swagger . Đăng nhập qua `/api/auth/login`, bấm **Authorize**, dán token.

Test: `cd backend && dotnet test`. Ứng dụng không tự migrate khi khởi động.

## Endpoint (prefix `/api`)

| Method | Path | Auth | Ghi chú |
|---|---|---|---|
| POST | /auth/register | - | `{username,email,password,fullName?}` -> `{token,user}` |
| POST | /auth/login | - | `{usernameOrEmail,password}` -> `{token,user}` (giới hạn 10 req/phút/IP) |
| GET/PUT | /users/me | JWT | PUT `{fullName?,avatarUrl?}` |
| PUT | /users/me/password | JWT | `{currentPassword,newPassword}` -> 204. Sai mật khẩu hiện tại / trùng mật khẩu cũ -> 400. 5 lượt/15 phút/người |
| GET | /users/search?q= | JWT | q >= 2 ký tự, tối đa 20 kết quả, bỏ qua chính mình |
| GET | /games | - | Danh sách game kèm level |
| POST | /history | JWT | `{gameCode,difficulty,timeSpentSeconds,mistakesCount,movesCount,hintsUsed,result,challengeId?}` -> bản ghi + `isPersonalBest` |
| GET | /history/me?gameCode=&page=&pageSize= | JWT | Mới nhất trước |
| GET | /leaderboard?gameCode=&board=ranked\|record&difficulty=&scope=global\|friends&period=season\|all&top=50 | - (JWT nếu scope=friends) | Đánh hạng kiểu thi đấu 1,2,2,4. Thiếu `board` = record; `period=week` = season |
| GET | /leaderboard/me?(cùng tham số) | JWT | `{rank,bestScore,bestTimeSeconds,rating?,tier?,tierName?,games?,wins?}`, cùng cách đánh hạng với danh sách |
| GET | /leaderboard/season | - | `{startUtc,endUtc,now}` của tuần lịch hiện tại (00:00 thứ Hai giờ VN, UTC+7) |
| GET | /friends | JWT | `[{userId,username,fullName,avatarUrl,status:online\|in_match\|offline,lastSeenAt,friendsSince}]`, online trước |
| GET | /friends/requests | JWT | `{incoming:[{requestId,userId,username,fullName,avatarUrl,createdAt}],outgoing:[...]}` |
| POST | /friends/requests | JWT | `{userId}` -> `{requestId,status:PENDING\|ACCEPTED,friend?}`. Bên kia đã mời mình -> tự ACCEPTED. 409 nếu đã là bạn / đã mời; 400 tự kết bạn; 404 không tồn tại |
| POST | /friends/requests/{id}/accept, /decline | JWT | Chỉ người nhận lời mời (nếu không 404); 409 nếu không còn PENDING |
| DELETE | /friends/{userId} | JWT | Hủy kết bạn (hoặc thu hồi lời mời đã gửi), 204 |
| GET | /users/{id}/profile | JWT | `{user,createdAt,isFriend,friendshipStatus:SELF\|NONE\|ACCEPTED\|PENDING_SENT\|PENDING_RECEIVED,pendingRequestId?,status,lastSeenAt,stats:[{gameCode,gameName,games,wins,losses,draws,bestRecordScore,rating,tier,tierName,peakRating,ratedGames}]}` |
| GET | /ratings/me | JWT | 4 game: `[{gameCode,gameName,rating,tier,tierName,games,wins,losses,draws,peakRating}]` |
| GET | /matches?page=&pageSize=20 | JWT | Lịch sử trận: `{items:[{matchId,gameCode,gameName,difficulty,mode,kind,opponent,result:WIN\|LOSE\|DRAW,endReason,ratingBefore,ratingAfter,ratingDelta,startedAt,endedAt,durationSeconds}],page,pageSize,total}` |
| POST | /challenges | JWT | `{opponentId,gameCode,difficulty}` -> ChallengeDto (PENDING). 10 lượt/giờ/người. **Chỉ giữa bạn bè** (403 nếu không) |
| GET | /challenges?box=incoming/outgoing/active/done/all | JWT | box=all trả mọi thách đấu của tôi (app dùng 1 lệnh gọi này). Tối đa 100, mới nhất trước; PENDING quá 7 ngày tự thành EXPIRED |
| GET | /challenges/{id} | JWT | Chỉ người tham gia |
| POST | /challenges/{id}/accept, /decline | JWT | Chỉ người được thách, chỉ khi PENDING |
| GET | /messages/conversations | JWT | Đối tác, tin cuối, `unreadCount` |
| GET | /messages/with/{userId}?afterId=&beforeId=&limit=30 | JWT | Tăng dần theo `messageId` |
| POST | /messages/with/{userId} | JWT | `{content}` 1..1000 ký tự. 20 tin/phút/người. **Chỉ giữa bạn bè**, nếu không 403 "Chỉ nhắn tin / thách đấu với bạn bè". Đẩy `MessageReceived` cho người nhận |
| POST | /messages/with/{userId}/read | JWT | Đánh dấu tin đến là đã đọc (204) |
| GET | /social/summary | JWT | `{unreadMessages,incomingChallenges,activeChallenges}` cho huy hiệu |

Thách đấu (chỉ giữa bạn bè): hai bên chơi cùng một đề sinh từ seed = `challengeId`; gửi kết quả bằng `POST /history` kèm `challengeId` (phải ACCEPTED, mỗi người nộp 1 lần, nếu không 409). Khi đủ hai bên, server chọn người thắng (điểm cao hơn; bằng điểm thì thời gian ngắn hơn; còn lại hoà) và đặt COMPLETED; phản hồi có thêm `challenge`. Cần chạy `db/migrations/002_social.sql` (chỉ mục, chạy lại được).

`result`: `COMPLETED | WIN | LOSE | DRAW | ABANDONED`. Lỗi trả về dạng ProblemDetails (RFC 7807).

## Công thức điểm v2 (server tính, `ScoreCalculator`)

```
base            = {1: 1000, 2: 2000, 3: 3000}[difficulty]
hệ số thời gian = clamp(par / thời gian thực, 0.25, 1.5)
hệ số lỗi       = 0.92 ^ số lỗi
điểm            = round(base × hệ số thời gian × hệ số lỗi)
LOSE / ABANDONED = 0
```

| Game | Par Dễ | Par Vừa | Par Khó |
|---|---|---|---|
| SUDOKU | 360 s | 720 s | 1500 s |
| PUZZLE | 60 s | 240 s | 600 s |
| RUBIK | 90 s | 240 s | 600 s |
| CARO | không dùng thời gian: par theo **số nước của mình** 20 / 30 / 45 (thiếu `movesCount` = coi như đúng par) | | |

Caro `DRAW` = 30% điểm. Bảng **Kỷ lục** chỉ tính lượt chơi đơn `COMPLETED`/`WIN` (bỏ qua dòng History của trận PvP có `match_id`, vì thời gian đua do client báo) của tài khoản còn hoạt động: mỗi người một dòng tốt nhất; bằng điểm thì thời gian ngắn hơn, rồi người đạt trước. Không chọn độ khó = gộp mọi độ khó.

## Bảng xếp hạng và mùa

- Mùa = tuần lịch, bắt đầu 00:00 thứ Hai giờ Việt Nam (UTC+7).
- `board=ranked`: xếp theo `PlayerRatings.rating`; bằng nhau thì nhiều thắng hơn, rồi cập nhật sớm hơn. `period=season` chỉ gồm người có trận Xếp hạng trong mùa; `all` gồm người có >= 1 trận xếp hạng.
- `scope=friends` cần đăng nhập, gồm bạn bè đã chấp nhận và chính mình.
- Đánh hạng 1,2,2,4 cho cả danh sách và `/leaderboard/me` (dùng chung `LeaderboardRules`).

## Elo và bậc rank

- Rating khởi điểm 1000 (mỗi game một rating). Chỉ trận **RANKED** (tìm trận nhanh) đổi rating; **FRIENDLY** (mời bạn) thì không.
- `K = 40` cho 10 trận xếp hạng đầu, sau đó `K = 24`. Thắng 1 / hòa 0.5 / thua 0; bỏ trận (ABANDON) tính là thua.
- Bậc: `BRONZE` Đồng < 1100 · `SILVER` Bạc < 1250 · `GOLD` Vàng < 1400 · `PLATINUM` Bạch kim < 1600 · `DIAMOND` Kim cương >= 1600.

## Realtime: SignalR `/hubs/game`

Kết nối WebSocket hoặc LongPolling, JWT qua query `?access_token=<token>`. User id = claim `sub`. Trạng thái trận nằm **trong bộ nhớ**; DB chỉ được ghi khi trận kết thúc (một transaction: `Matches` + 2 dòng `History` + upsert `PlayerRatings`) và khi gọi REST. `last_seen_at` ghi tối đa 1 lần/60 giây/người. Đồng hồ (hết lượt, kết nối lại, lời mời, hàng đợi) do `MatchTicker` chạy mỗi giây, không đụng DB. `matchId` và `inviteId` là **chuỗi** (GUID dạng hex 32 ký tự).

**Client gọi lên (lỗi nghiệp vụ = `HubException` với thông điệp tiếng Việt):**

| Phương thức | Ghi chú |
|---|---|
| `QueueJoin(gameCode, difficulty)`, `QueueLeave()` | Hàng đợi Xếp hạng; nới khoảng rating 100 -> 200 -> 400 -> không giới hạn ở 0/10/20/30 s |
| `Invite(friendId, gameCode, difficulty)` -> `inviteId` | Giao hữu; bạn bè phải online; hết hạn 30 s |
| `RespondInvite(inviteId, accept)` | |
| `CaroMove(matchId, row, col)` | bàn 15x15, row/col 0..14 |
| `RaceProgress(matchId, percent)`, `RaceFinish(matchId, timeMs, mistakes)` | |
| `Resign(matchId)`, `OfferDraw(matchId)`, `RespondDraw(matchId, accept)` | |
| `Rematch(matchId)`, `QuickChat(matchId, code)`, `Rejoin(matchId)` | |

**Server đẩy xuống:**

```
Presence(userId, status)                       // status: online | in_match | offline (chỉ tới bạn bè)
FriendRequest({requestId, from:{userId,username,fullName,avatarUrl}, createdAt})
FriendAccepted({requestId, user:{userId,username,fullName,avatarUrl}})
MessageReceived({messageId, senderId, receiverId, content, isRead, sentAt})
InviteReceived({inviteId, from:{...}, gameCode, difficulty, expiresAtUtc, expiresInSec})
InviteResult({inviteId, status:"accepted"|"declined"|"expired", userId, gameCode, difficulty, matchId?})
QueueStatus(searching, waitedSec, range)       // range: 100/200/400, 0 = không giới hạn; mỗi ~3 s
MatchStarted(match) / MatchState(match)
OpponentProgress({matchId, userId, percent})
QuickChat({matchId, fromUserId, code})         // code: hello|nice|gg|rematch|oops|thanks (1 tin/2 s)
OpponentConnection(connected, graceSec)        // false,30 khi đối thủ rớt; true,0 khi quay lại
DrawOffered({matchId, fromUserId}), DrawResponded({matchId, accepted, byUserId})
RematchRequested({matchId, fromUserId})
MatchEnded({matchId, winnerId|null, reason, mode, ratingChanges:[{userId,before,after}], results:[{userId,result,score}]})
```

Payload `match` (MatchStarted / MatchState), `you` là userId của người nhận:

```json
{"matchId":"a1b2...","gameCode":"CARO","difficulty":2,"mode":"RANKED","kind":"TURN","seed":123456,
 "status":"ACTIVE","startedAtUtc":"2026-10-21T03:00:00Z","you":1,
 "players":[{"userId":1,"username":"an","fullName":"An","avatarUrl":null,"rating":1000,"tier":"BRONZE","tierName":"Đồng","connected":true},{"userId":2,"...":"..."}],
 "caro":{"size":15,"moves":[{"row":7,"col":7,"userId":1}],"currentTurnUserId":2,"turnDeadlineUtc":"2026-10-21T03:00:30Z","drawOfferedBy":null},
 "race":null}
```

Trận đua (`"kind":"RACE"`, SUDOKU/PUZZLE/RUBIK): `caro` là `null`, `race = {"progress":[{"userId":1,"percent":40},...],"deadlineUtc":"..."}`; hai bên dùng cùng `seed` (> 0). Mỗi nước Caro hợp lệ server gửi `MatchState` đầy đủ cho cả hai bên.

Luật:
- Caro: người đi trước ngẫu nhiên; 5 quân liên tiếp trở lên (không chặn hai đầu) thắng; 30 s/nước, quá giờ thua (`TIMEOUT`); bàn đầy = hòa; xin hòa tối đa 3 lần/người, đi tiếp coi như từ chối.
- Đua giải: `RaceProgress` tối đa 4 lần/giây (gọi dày hơn bị bỏ qua), chỉ tăng. `RaceFinish` hợp lệ khi tiến độ đã >= 90, `timeMs` >= thời gian tối thiểu hợp lý (Sudoku 30 s; Xếp hình 5/20/40 s theo độ khó; Rubik 5/10/15 s), thời gian trận trên server cũng >= mức đó và `timeMs` không vượt quá thời gian trận thật + 3 s. Người đầu tiên hợp lệ thắng. Quá 15 phút (`TIME_LIMIT`): tiến độ cao hơn thắng, bằng nhau hòa.
- Mất kết nối (kết nối cuối của user đóng): 30 s để `Rejoin(matchId)` (server gửi lại `MatchState`); quá hạn thì xử thua (`ABANDON`, kết quả `ABANDONED`, 0 điểm).
- Tái đấu: cả hai gọi `Rematch(matchId)` trong 30 s sau khi trận kết thúc thì bắt đầu trận mới cùng game/độ khó/chế độ.
- `reason`: `WIN | TIMEOUT | RESIGN | DRAW | ABANDON | TIME_LIMIT | SERVER_RESTART` (server tắt: hủy trận, không ghi DB, không đổi rating).
- Một người chỉ ở một hàng đợi / một trận tại một thời điểm.

## Chạy migration 003 (bạn bè, rating, trận đấu)

Chạy **một lần** (script chạy lại được) trước khi dùng API mới; ứng dụng không tự migrate:
```
sqlcmd -S <server> -d doan_mobile -U <user> -P <password> -C -f 65001 -I -i db/migrations/003_pvp_friends.sql
```
Thêm `Users.last_seen_at`, `Friendships`, `PlayerRatings`, `Matches`, `History.match_id` và các chỉ mục bảng xếp hạng.

## Cấu hình bí mật (.env)

Chuỗi kết nối và khoá JWT **không** ghi trong `appsettings.json`. Sao chép `GameHub.Api/.env.example`
thành `GameHub.Api/.env` (đã có trong `.gitignore`) rồi điền giá trị thật:
```
ConnectionStrings__DefaultConnection=Server=...;Database=...;User Id=...;Password=...;TrustServerCertificate=True
Jwt__Key=<chuỗi ngẫu nhiên ≥ 32 ký tự>
```
Backend tự đọc file này khi khởi động; biến môi trường thật trên máy chủ được ưu tiên hơn.

## Deploy lên VPS Linux (chạy song song với ứng dụng khác)

- Chạy như một service systemd riêng (ví dụ `gamehub-api`), cổng riêng (ví dụ 5214), user riêng, giới hạn RAM.
- Bản .NET tự đóng gói nên không cần cài runtime trên máy chủ và không ảnh hưởng ứng dụng khác.
- Cấu hình bí mật đặt trong `.env` hoặc `appsettings.Production.json` **trên máy chủ** (quyền 640), không đưa vào git.
- Thông tin truy cập máy chủ (IP, tài khoản) **không ghi vào repo**.

```bash
# Trên máy phát triển
dotnet publish backend/GameHub.Api -c Release -r linux-x64 --self-contained true -o publish
# Xoá publish/appsettings.Development.json và publish/.env, nén thư mục, chép lên máy chủ. Trên máy chủ:
systemctl stop gamehub-api
tar -xzf gamehub.tar.gz -C /opt/gamehub && chown -R gamehub:gamehub /opt/gamehub
systemctl start gamehub-api
journalctl -u gamehub-api -f      # xem log
```
