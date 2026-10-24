-- CHỈ DÙNG KHI PHÁT TRIỂN: xoá toàn bộ bảng của GameHub (kể cả bảng cũ viết thường)
-- để chạy lại schema.sql từ đầu. MẤT HẾT DỮ LIỆU.
IF OBJECT_ID(N'dbo.vw_Leaderboard', N'V') IS NOT NULL DROP VIEW dbo.vw_Leaderboard;
DROP TABLE IF EXISTS dbo.History;
DROP TABLE IF EXISTS dbo.game_history;
DROP TABLE IF EXISTS dbo.Messages;
DROP TABLE IF EXISTS dbo.Challenges;
DROP TABLE IF EXISTS dbo.GameLevels;
DROP TABLE IF EXISTS dbo.game_levels;
DROP TABLE IF EXISTS dbo.Games;
DROP TABLE IF EXISTS dbo.Users;
GO
