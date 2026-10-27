namespace GameHub.Api.Services;

/// <summary>
/// Điểm kỷ lục v2 (TASKS_V2 §2.1):
/// điểm = round(base × clamp(par / thực tế, 0.25, 1.5) × 0.92^lỗi × 0.85^gợi ý); base = 1000/2000/3000.
/// Gợi ý phạt nặng hơn lỗi vì cho thẳng đáp án.
/// Sudoku/Xếp hình/Rubik: par theo thời gian (giây). Caro: par theo số nước đi (20/30/45).
/// LOSE/ABANDONED = 0; DRAW của Caro = 30%.
/// </summary>
public static class ScoreCalculator
{
    public static readonly string[] ValidResults = ["COMPLETED", "WIN", "LOSE", "DRAW", "ABANDONED"];

    public const double MinFactor = 0.25, MaxFactor = 1.5, MistakeFactor = 0.92, HintFactor = 0.85, CaroDrawRatio = 0.30;

    public static int BaseScore(int difficulty) => difficulty switch
    {
        1 => 1000,
        2 => 2000,
        3 => 3000,
        4 => 4000,
        _ => throw new ArgumentOutOfRangeException(nameof(difficulty)),
    };

    /// <summary>Thời gian chuẩn (giây) theo game và độ khó. Game lạ dùng bảng của Xếp hình.</summary>
    public static int ParSeconds(string? gameCode, int difficulty)
    {
        int[] table = (gameCode ?? "").ToUpperInvariant() switch
        {
            "SUDOKU" => [360, 720, 1500, 2400],
            "RUBIK" => [90, 240, 600],
            _ => [60, 240, 600], // PUZZLE
        };
        return table[Math.Clamp(difficulty, 1, table.Length) - 1];
    }

    /// <summary>Số nước chuẩn của Caro: 20 / 30 / 45.</summary>
    public static int ParMoves(int difficulty) => new[] { 20, 30, 45 }[Math.Clamp(difficulty, 1, 3) - 1];

    public static int Calculate(int difficulty, int timeSpentSeconds, int mistakesCount, string result,
        string? gameCode = null, int movesCount = 0, int hintsUsed = 0)
    {
        if (result is "ABANDONED" or "LOSE") return 0;
        var b = BaseScore(difficulty);
        var isCaro = string.Equals(gameCode, "CARO", StringComparison.OrdinalIgnoreCase);

        double factor;
        if (isCaro)
            // Không có số nước (client cũ) -> coi như đúng par.
            factor = movesCount <= 0 ? 1.0 : Clamp((double)ParMoves(difficulty) / movesCount);
        else
            factor = Clamp((double)ParSeconds(gameCode, difficulty) / Math.Max(timeSpentSeconds, 1));

        var score = b * factor * Math.Pow(MistakeFactor, Math.Max(mistakesCount, 0))
                    * Math.Pow(HintFactor, Math.Max(hintsUsed, 0));
        if (result == "DRAW" && isCaro) score *= CaroDrawRatio;
        return (int)Math.Round(score, MidpointRounding.AwayFromZero);
    }

    private static double Clamp(double v) => Math.Clamp(v, MinFactor, MaxFactor);
}
