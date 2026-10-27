using System.ComponentModel.DataAnnotations;
using GameHub.Api.Services;

namespace GameHub.Api.model;

public record SudokuLevelDto(int Level, int Clues, bool IsUnlocked, int? BestTimeSeconds, bool IsCompleted, DateTime? CompletedAt);

public record SudokuProgressSummaryDto(int CompletedCount, int HighestUnlockedLevel, List<SudokuLevelDto> Levels);

public record UpdateSudokuProgressRequest(
    [Range(1, 30, ErrorMessage = "Level phải từ 1 đến 30")] int Level,
    [Range(1, 86400, ErrorMessage = "Thời gian chơi không hợp lệ")] int TimeSpentSeconds,
    [Range(0, 3, ErrorMessage = "Số lỗi từ 0 đến 3")] int Mistakes);

public record UpdateSudokuProgressResponse(
    bool Success,
    bool IsNewBest,
    int? BestTimeSeconds,
    int HighestUnlockedLevel,
    string Message);

public record SaveSudokuGameRequest(
    [Required] string GameMode,
    int? Level,
    [Range(1, DifficultyRules.SudokuMax)] int Difficulty,
    long Seed,
    [Required, StringLength(81, MinimumLength = 81)] string BoardCurrent,
    string? NotesData,
    [Range(0, 3)] int Mistakes,
    [Range(0, 86400)] int ElapsedSeconds);

public record SudokuSavedGameDto(
    int Id,
    string GameMode,
    int? Level,
    int Difficulty,
    long Seed,
    string BoardCurrent,
    string? NotesData,
    int Mistakes,
    int ElapsedSeconds,
    DateTime UpdatedAt);

public record DifficultyStatsDto(
    int Difficulty,
    int GamesStarted,
    int GamesWon,
    int WinWithoutMistakes,
    int? BestTimeSeconds,
    int TotalWinTimeSeconds);

public record RecordSudokuStatRequest(
    [Range(1, DifficultyRules.SudokuMax, ErrorMessage = "Độ khó từ 1 đến 5")] int Difficulty,
    bool IsGameStarted,
    bool IsWin,
    [Range(0, 86400)] int ElapsedSeconds,
    [Range(0, 100)] int Mistakes);
