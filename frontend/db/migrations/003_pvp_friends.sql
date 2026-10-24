-- 003_pvp_friends.sql: bạn bè, rating Elo, trận đấu 1-1 (PvP). Chạy lại nhiều lần không lỗi.
-- Chạy: sqlcmd -S <server> -d doan_mobile -U <user> -P <password> -C -f 65001 -I -i db/migrations/003_pvp_friends.sql
-- Tất cả khóa ngoại dùng ON DELETE NO ACTION.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- 1) Users.last_seen_at
IF COL_LENGTH(N'dbo.Users', N'last_seen_at') IS NULL
    ALTER TABLE dbo.Users ADD last_seen_at DATETIME2 NULL;
GO

-- 2) Friendships: mỗi cặp người chỉ có một dòng (user_low < user_high, unique)
IF OBJECT_ID(N'dbo.Friendships', N'U') IS NULL
CREATE TABLE dbo.Friendships (
    friendship_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Friendships PRIMARY KEY,
    requester_id  INT NOT NULL CONSTRAINT FK_Friendships_requester REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    addressee_id  INT NOT NULL CONSTRAINT FK_Friendships_addressee REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    user_low      INT NOT NULL,
    user_high     INT NOT NULL,
    status        VARCHAR(20) NOT NULL CONSTRAINT DF_Friendships_status DEFAULT 'PENDING'
                  CONSTRAINT CK_Friendships_status CHECK (status IN ('PENDING','ACCEPTED','DECLINED')),
    created_at    DATETIME2 NOT NULL CONSTRAINT DF_Friendships_created_at DEFAULT SYSUTCDATETIME(),
    responded_at  DATETIME2 NULL,
    CONSTRAINT CK_Friendships_distinct CHECK (requester_id <> addressee_id),
    CONSTRAINT CK_Friendships_pair CHECK (user_low < user_high)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Friendships_pair' AND object_id = OBJECT_ID(N'dbo.Friendships'))
    CREATE UNIQUE INDEX UX_Friendships_pair ON dbo.Friendships(user_low, user_high);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Friendships_requester' AND object_id = OBJECT_ID(N'dbo.Friendships'))
    CREATE INDEX IX_Friendships_requester ON dbo.Friendships(requester_id, status);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Friendships_addressee' AND object_id = OBJECT_ID(N'dbo.Friendships'))
    CREATE INDEX IX_Friendships_addressee ON dbo.Friendships(addressee_id, status);
GO

-- 3) PlayerRatings: rating Elo theo (người chơi, game); chỉ trận Xếp hạng mới đổi
IF OBJECT_ID(N'dbo.PlayerRatings', N'U') IS NULL
CREATE TABLE dbo.PlayerRatings (
    user_id     INT NOT NULL CONSTRAINT FK_PlayerRatings_Users REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    game_id     INT NOT NULL CONSTRAINT FK_PlayerRatings_Games REFERENCES dbo.Games(game_id) ON DELETE NO ACTION,
    rating      INT NOT NULL CONSTRAINT DF_PlayerRatings_rating DEFAULT 1000,
    games       INT NOT NULL CONSTRAINT DF_PlayerRatings_games  DEFAULT 0,
    wins        INT NOT NULL CONSTRAINT DF_PlayerRatings_wins   DEFAULT 0,
    losses      INT NOT NULL CONSTRAINT DF_PlayerRatings_losses DEFAULT 0,
    draws       INT NOT NULL CONSTRAINT DF_PlayerRatings_draws  DEFAULT 0,
    peak_rating INT NOT NULL CONSTRAINT DF_PlayerRatings_peak   DEFAULT 1000,
    updated_at  DATETIME2 NOT NULL CONSTRAINT DF_PlayerRatings_updated DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_PlayerRatings PRIMARY KEY (user_id, game_id)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_PlayerRatings_game_rating' AND object_id = OBJECT_ID(N'dbo.PlayerRatings'))
    CREATE INDEX IX_PlayerRatings_game_rating ON dbo.PlayerRatings(game_id, rating DESC);
GO

-- 4) Matches: một dòng cho mỗi trận đã kết thúc (ghi một lần khi kết thúc)
IF OBJECT_ID(N'dbo.Matches', N'U') IS NULL
CREATE TABLE dbo.Matches (
    match_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Matches PRIMARY KEY,
    game_id          INT NOT NULL CONSTRAINT FK_Matches_Games REFERENCES dbo.Games(game_id) ON DELETE NO ACTION,
    difficulty       INT NOT NULL CONSTRAINT CK_Matches_difficulty CHECK (difficulty BETWEEN 1 AND 3),
    mode             VARCHAR(10) NOT NULL CONSTRAINT CK_Matches_mode CHECK (mode IN ('RANKED','FRIENDLY')),
    kind             VARCHAR(10) NOT NULL CONSTRAINT CK_Matches_kind CHECK (kind IN ('TURN','RACE')),
    player1_id       INT NOT NULL CONSTRAINT FK_Matches_p1 REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    player2_id       INT NOT NULL CONSTRAINT FK_Matches_p2 REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    winner_id        INT NULL     CONSTRAINT FK_Matches_winner REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    end_reason       VARCHAR(20) NOT NULL,
    seed             INT NOT NULL,
    started_at       DATETIME2 NOT NULL,
    ended_at         DATETIME2 NOT NULL,
    p1_rating_before INT NULL,
    p1_rating_after  INT NULL,
    p2_rating_before INT NULL,
    p2_rating_after  INT NULL,
    CONSTRAINT CK_Matches_distinct CHECK (player1_id <> player2_id)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Matches_p1' AND object_id = OBJECT_ID(N'dbo.Matches'))
    CREATE INDEX IX_Matches_p1 ON dbo.Matches(player1_id, ended_at DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Matches_p2' AND object_id = OBJECT_ID(N'dbo.Matches'))
    CREATE INDEX IX_Matches_p2 ON dbo.Matches(player2_id, ended_at DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Matches_game_mode_ended' AND object_id = OBJECT_ID(N'dbo.Matches'))
    CREATE INDEX IX_Matches_game_mode_ended ON dbo.Matches(game_id, mode, ended_at DESC);
GO

-- 5) History.match_id (NULL) + khóa ngoại tới Matches
IF COL_LENGTH(N'dbo.History', N'match_id') IS NULL
    ALTER TABLE dbo.History ADD match_id INT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_History_Matches' AND parent_object_id = OBJECT_ID(N'dbo.History'))
    ALTER TABLE dbo.History ADD CONSTRAINT FK_History_Matches FOREIGN KEY (match_id) REFERENCES dbo.Matches(match_id) ON DELETE NO ACTION;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_History_match' AND object_id = OBJECT_ID(N'dbo.History'))
    CREATE INDEX IX_History_match ON dbo.History(match_id) WHERE match_id IS NOT NULL;
GO

-- Bảng xếp hạng kỷ lục: lọc theo game + kết quả, sắp theo điểm và thời điểm chơi
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_History_game_result_played' AND object_id = OBJECT_ID(N'dbo.History'))
    CREATE INDEX IX_History_game_result_played ON dbo.History(game_id, result, played_at) INCLUDE (user_id, level_id, score, time_spent_seconds);
GO
