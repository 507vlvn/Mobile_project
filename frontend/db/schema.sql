-- GameHub schema (SQL Server T-SQL). Chay duoc nhieu lan (idempotent).
-- Tat ca FK dung ON DELETE NO ACTION (tranh loi 1785 multiple cascade paths).
-- User bi xoa mem bang Users.is_active.

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
CREATE TABLE dbo.Users (
    user_id       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
    username      VARCHAR(50)   NOT NULL CONSTRAINT UQ_Users_username UNIQUE,
    password_hash VARCHAR(255)  NOT NULL,
    email         VARCHAR(100)  NOT NULL CONSTRAINT UQ_Users_email UNIQUE,
    full_name     NVARCHAR(100) NULL,
    avatar_url    VARCHAR(255)  NULL,
    is_active     BIT           NOT NULL CONSTRAINT DF_Users_is_active DEFAULT 1,
    created_at    DATETIME2     NOT NULL CONSTRAINT DF_Users_created_at DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID(N'dbo.Games', N'U') IS NULL
CREATE TABLE dbo.Games (
    game_id     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Games PRIMARY KEY,
    game_code   VARCHAR(50)   NOT NULL CONSTRAINT UQ_Games_game_code UNIQUE, -- RUBIK, SUDOKU, PUZZLE, CARO
    game_name   NVARCHAR(100) NOT NULL,
    description NVARCHAR(MAX) NULL
);
GO

-- Nhieu dong cho moi (game, difficulty) duoc phep (vd: do Sudoku luu san).
IF OBJECT_ID(N'dbo.GameLevels', N'U') IS NULL
CREATE TABLE dbo.GameLevels (
    level_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GameLevels PRIMARY KEY,
    game_id         INT NOT NULL CONSTRAINT FK_GameLevels_Games REFERENCES dbo.Games(game_id) ON DELETE NO ACTION,
    difficulty      INT NOT NULL CONSTRAINT CK_GameLevels_difficulty CHECK (difficulty BETWEEN 1 AND 3), -- 1=De, 2=Vua, 3=Kho
    difficulty_name NVARCHAR(20) NOT NULL CONSTRAINT DF_GameLevels_difficulty_name DEFAULT N'Vừa',
    initial_state   NVARCHAR(MAX) NULL,
    solution_data   NVARCHAR(MAX) NULL
);
GO

IF OBJECT_ID(N'dbo.Challenges', N'U') IS NULL
CREATE TABLE dbo.Challenges (
    challenge_id  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Challenges PRIMARY KEY,
    challenger_id INT NOT NULL CONSTRAINT FK_Challenges_challenger REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    opponent_id   INT NOT NULL CONSTRAINT FK_Challenges_opponent   REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    game_id       INT NOT NULL CONSTRAINT FK_Challenges_Games      REFERENCES dbo.Games(game_id) ON DELETE NO ACTION,
    level_id      INT NULL     CONSTRAINT FK_Challenges_GameLevels REFERENCES dbo.GameLevels(level_id) ON DELETE NO ACTION,
    status        VARCHAR(20) NOT NULL CONSTRAINT DF_Challenges_status DEFAULT 'PENDING'
                  CONSTRAINT CK_Challenges_status CHECK (status IN ('PENDING','ACCEPTED','DECLINED','COMPLETED','EXPIRED')),
    winner_id     INT NULL     CONSTRAINT FK_Challenges_winner     REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    created_at    DATETIME2 NOT NULL CONSTRAINT DF_Challenges_created_at DEFAULT SYSUTCDATETIME(),
    accepted_at   DATETIME2 NULL,
    completed_at  DATETIME2 NULL,
    CONSTRAINT CK_Challenges_distinct CHECK (challenger_id <> opponent_id)
);
GO

IF OBJECT_ID(N'dbo.History', N'U') IS NULL
CREATE TABLE dbo.History (
    history_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_History PRIMARY KEY,
    user_id            INT NOT NULL CONSTRAINT FK_History_Users      REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    game_id            INT NOT NULL CONSTRAINT FK_History_Games      REFERENCES dbo.Games(game_id) ON DELETE NO ACTION,
    level_id           INT NULL     CONSTRAINT FK_History_GameLevels REFERENCES dbo.GameLevels(level_id) ON DELETE NO ACTION,
    challenge_id       INT NULL     CONSTRAINT FK_History_Challenges REFERENCES dbo.Challenges(challenge_id) ON DELETE NO ACTION,
    time_spent_seconds INT NOT NULL CONSTRAINT CK_History_time CHECK (time_spent_seconds >= 0),
    mistakes_count     INT NOT NULL CONSTRAINT DF_History_mistakes DEFAULT 0 CONSTRAINT CK_History_mistakes CHECK (mistakes_count >= 0),
    moves_count        INT NOT NULL CONSTRAINT DF_History_moves DEFAULT 0,
    hints_used         INT NOT NULL CONSTRAINT DF_History_hints DEFAULT 0,
    result             VARCHAR(20) NOT NULL CONSTRAINT CK_History_result CHECK (result IN ('COMPLETED','WIN','LOSE','DRAW','ABANDONED')),
    score              INT NOT NULL,
    played_at          DATETIME2 NOT NULL CONSTRAINT DF_History_played_at DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID(N'dbo.Messages', N'U') IS NULL
CREATE TABLE dbo.Messages (
    message_id  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Messages PRIMARY KEY,
    sender_id   INT NOT NULL CONSTRAINT FK_Messages_sender   REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    receiver_id INT NOT NULL CONSTRAINT FK_Messages_receiver REFERENCES dbo.Users(user_id) ON DELETE NO ACTION,
    content     NVARCHAR(2000) NOT NULL,
    is_read     BIT NOT NULL CONSTRAINT DF_Messages_is_read DEFAULT 0,
    sent_at     DATETIME2 NOT NULL CONSTRAINT DF_Messages_sent_at DEFAULT SYSUTCDATETIME()
);
GO

-- Indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_History_game_level_score' AND object_id = OBJECT_ID(N'dbo.History'))
    CREATE INDEX IX_History_game_level_score ON dbo.History(game_id, level_id, score DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_History_user_played' AND object_id = OBJECT_ID(N'dbo.History'))
    CREATE INDEX IX_History_user_played ON dbo.History(user_id, played_at DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Messages_pair_sent' AND object_id = OBJECT_ID(N'dbo.Messages'))
    CREATE INDEX IX_Messages_pair_sent ON dbo.Messages(sender_id, receiver_id, sent_at);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Challenges_opponent_status' AND object_id = OBJECT_ID(N'dbo.Challenges'))
    CREATE INDEX IX_Challenges_opponent_status ON dbo.Challenges(opponent_id, status);
GO

-- Seed Games
MERGE dbo.Games AS t
USING (VALUES ('RUBIK', N'Rubik 3x3'), ('SUDOKU', N'Sudoku'), ('PUZZLE', N'Xếp hình'), ('CARO', N'Caro')) AS s(game_code, game_name)
ON t.game_code = s.game_code
WHEN NOT MATCHED THEN INSERT (game_code, game_name) VALUES (s.game_code, s.game_name);
GO

-- Seed 3 level mac dinh moi game (chi them khi game+difficulty chua co dong nao)
INSERT INTO dbo.GameLevels (game_id, difficulty, difficulty_name)
SELECT g.game_id, d.difficulty, d.difficulty_name
FROM dbo.Games g
CROSS JOIN (VALUES (1, N'Dễ'), (2, N'Vừa'), (3, N'Khó')) AS d(difficulty, difficulty_name)
WHERE NOT EXISTS (SELECT 1 FROM dbo.GameLevels l WHERE l.game_id = g.game_id AND l.difficulty = d.difficulty);
GO

-- Bang xep hang (moi thoi gian). Chi tai khoan active, ket qua COMPLETED/WIN.
-- best_score = diem cao nhat; best_time_seconds = thoi gian cua luot co diem cao nhat
-- (hoa diem thi lay thoi gian ngan nhat); plays_count = so luot hop le.
CREATE OR ALTER VIEW dbo.vw_Leaderboard AS
WITH ranked AS (
    SELECT h.user_id, h.game_id, l.difficulty, h.score, h.time_spent_seconds,
           ROW_NUMBER() OVER (PARTITION BY h.user_id, h.game_id, l.difficulty
                              ORDER BY h.score DESC, h.time_spent_seconds ASC) AS rn,
           COUNT(*) OVER (PARTITION BY h.user_id, h.game_id, l.difficulty) AS plays_count
    FROM dbo.History h
    JOIN dbo.GameLevels l ON l.level_id = h.level_id
    WHERE h.result IN ('COMPLETED','WIN')
)
SELECT r.user_id, u.username, u.full_name, u.avatar_url,
       r.game_id, g.game_code, r.difficulty,
       r.score AS best_score, r.time_spent_seconds AS best_time_seconds, r.plays_count
FROM ranked r
JOIN dbo.Users u ON u.user_id = r.user_id AND u.is_active = 1
JOIN dbo.Games g ON g.game_id = r.game_id
WHERE r.rn = 1;
GO
