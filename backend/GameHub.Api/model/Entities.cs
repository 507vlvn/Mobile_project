namespace GameHub.Api.model;

public class User
{
    public int UserId { get; set; }
    public string Username { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string Email { get; set; } = "";
    public string? FullName { get; set; }
    public string? AvatarUrl { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastSeenAt { get; set; }
}

public class Game
{
    public int GameId { get; set; }
    public string GameCode { get; set; } = "";
    public string GameName { get; set; } = "";
    public string? Description { get; set; }
    public List<GameLevel> Levels { get; set; } = [];
}

public class GameLevel
{
    public int LevelId { get; set; }
    public int GameId { get; set; }
    public int Difficulty { get; set; }
    public string DifficultyName { get; set; } = "Vừa";
    public string? InitialState { get; set; }
    public string? SolutionData { get; set; }
    public Game Game { get; set; } = null!;
}

public class HistoryEntry
{
    public int HistoryId { get; set; }
    public int UserId { get; set; }
    public int GameId { get; set; }
    public int? LevelId { get; set; }
    public int? ChallengeId { get; set; }
    public int? MatchId { get; set; }
    public int TimeSpentSeconds { get; set; }
    public int MistakesCount { get; set; }
    public int MovesCount { get; set; }
    public int HintsUsed { get; set; }
    public string Result { get; set; } = "";
    public int Score { get; set; }
    public DateTime PlayedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
    public Game Game { get; set; } = null!;
    public GameLevel? Level { get; set; }
    public GameMatch? Match { get; set; }
}

public class Challenge
{
    public int ChallengeId { get; set; }
    public int ChallengerId { get; set; }
    public int OpponentId { get; set; }
    public int GameId { get; set; }
    public int? LevelId { get; set; }
    public string Status { get; set; } = "PENDING";
    public int? WinnerId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? AcceptedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public User Challenger { get; set; } = null!;
    public User Opponent { get; set; } = null!;
    public Game Game { get; set; } = null!;
    public GameLevel? Level { get; set; }
}

public class Message
{
    public int MessageId { get; set; }
    public int SenderId { get; set; }
    public int ReceiverId { get; set; }
    public string Content { get; set; } = "";
    public bool IsRead { get; set; }
    public DateTime SentAt { get; set; } = DateTime.UtcNow;
}

/// <summary>Mỗi cặp người chơi chỉ có một dòng (UserLowId &lt; UserHighId, unique).</summary>
public class Friendship
{
    public const string Pending = "PENDING", Accepted = "ACCEPTED", Declined = "DECLINED";

    public int FriendshipId { get; set; }
    public int RequesterId { get; set; }
    public int AddresseeId { get; set; }
    public int UserLowId { get; set; }
    public int UserHighId { get; set; }
    public string Status { get; set; } = Pending;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? RespondedAt { get; set; }

    public User Requester { get; set; } = null!;
    public User Addressee { get; set; } = null!;

    public static (int Low, int High) Pair(int a, int b) => a < b ? (a, b) : (b, a);

    public void SetPair(int requester, int addressee)
    {
        RequesterId = requester;
        AddresseeId = addressee;
        (UserLowId, UserHighId) = Pair(requester, addressee);
    }

    public int OtherThan(int me) => RequesterId == me ? AddresseeId : RequesterId;
}

public class PlayerRating
{
    public int UserId { get; set; }
    public int GameId { get; set; }
    public int Rating { get; set; } = 1000;
    public int Games { get; set; }
    public int Wins { get; set; }
    public int Losses { get; set; }
    public int Draws { get; set; }
    public int PeakRating { get; set; } = 1000;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class GameMatch
{
    public int MatchId { get; set; }
    public int GameId { get; set; }
    public int Difficulty { get; set; }
    public string Mode { get; set; } = "RANKED";     // RANKED | FRIENDLY
    public string Kind { get; set; } = "TURN";       // TURN | RACE
    public int Player1Id { get; set; }
    public int Player2Id { get; set; }
    public int? WinnerId { get; set; }
    public string EndReason { get; set; } = "";
    public int Seed { get; set; }
    public DateTime StartedAt { get; set; }
    public DateTime EndedAt { get; set; }
    public int? P1RatingBefore { get; set; }
    public int? P1RatingAfter { get; set; }
    public int? P2RatingBefore { get; set; }
    public int? P2RatingAfter { get; set; }
}

public class SudokuProgress
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int Level { get; set; }
    public bool IsUnlocked { get; set; }
    public int? BestTimeSeconds { get; set; }
    public int? Mistakes { get; set; }
    public DateTime? CompletedAt { get; set; }
    public User User { get; set; } = null!;
}

public class SudokuSavedGame
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string GameMode { get; set; } = "CLASSIC";
    public int? Level { get; set; }
    public int Difficulty { get; set; }
    public long Seed { get; set; }
    public string BoardCurrent { get; set; } = "";
    public string? NotesData { get; set; }
    public int Mistakes { get; set; }
    public int ElapsedSeconds { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
}

public class SudokuDifficultyStat
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int Difficulty { get; set; } // 1: Dễ, 2: Trung bình, 3: Khó, 4: Chuyên gia
    public int GamesStarted { get; set; }
    public int GamesWon { get; set; }
    public int WinWithoutMistakes { get; set; }
    public int? BestTimeSeconds { get; set; }
    public int TotalWinTimeSeconds { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
}


public class CaroSavedGame
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string GameMode { get; set; } = "pve";
    public int Difficulty { get; set; }
    public bool PlayerFirst { get; set; }
    public string HistoryData { get; set; } = "[]";
    public int Undos { get; set; }
    public int ElapsedSeconds { get; set; }
    public int HintsRemaining { get; set; } = 3;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
}