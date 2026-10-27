namespace GameHub.Api.model;

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
