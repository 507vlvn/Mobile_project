-- 002_social.sql: chỉ mục cho Thách đấu và Tin nhắn (P11). Chạy lại nhiều lần không lỗi.
-- Chỉ mục có điều kiện (filtered index) bắt buộc QUOTED_IDENTIFIER ON (sqlcmd mặc định OFF).
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Chạy: sqlcmd -S <server> -d doan_mobile -U <user> -P <password> -C -f 65001 -i db/migrations/002_social.sql

-- Đếm tin chưa đọc + lấy hội thoại theo người nhận
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Messages_receiver_read' AND object_id = OBJECT_ID(N'dbo.Messages'))
    CREATE INDEX IX_Messages_receiver_read ON dbo.Messages(receiver_id, is_read) INCLUDE (sender_id);
GO

-- Hội thoại 2 chiều: (receiver_id, sender_id, message_id) để tải theo cặp + phân trang theo message_id
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Messages_receiver_sender_id' AND object_id = OBJECT_ID(N'dbo.Messages'))
    CREATE INDEX IX_Messages_receiver_sender_id ON dbo.Messages(receiver_id, sender_id, message_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Messages_sender_receiver_id' AND object_id = OBJECT_ID(N'dbo.Messages'))
    CREATE INDEX IX_Messages_sender_receiver_id ON dbo.Messages(sender_id, receiver_id, message_id);
GO

-- Danh sách thách đấu theo người thách
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Challenges_challenger_status' AND object_id = OBJECT_ID(N'dbo.Challenges'))
    CREATE INDEX IX_Challenges_challenger_status ON dbo.Challenges(challenger_id, status);
GO

SET QUOTED_IDENTIFIER ON;
-- Mỗi người chỉ nộp 1 kết quả cho mỗi thách đấu (chặn nộp trùng khi 2 request đồng thời)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_History_challenge_user' AND object_id = OBJECT_ID(N'dbo.History'))
    CREATE UNIQUE INDEX UX_History_challenge_user ON dbo.History(challenge_id, user_id) WHERE challenge_id IS NOT NULL;
GO
