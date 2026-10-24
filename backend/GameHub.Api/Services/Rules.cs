namespace GameHub.Api.Services;

/// <summary>Luật Caro tự do: bàn 15x15, đủ 5 quân liên tiếp trở lên là thắng (không chặn hai đầu).</summary>
public static class CaroRules
{
    public const int Size = 15, WinLength = 5, MoveSeconds = 30;

    private static readonly (int dr, int dc)[] Directions = [(0, 1), (1, 0), (1, 1), (1, -1)];

    /// <summary>board[row * Size + col] = userId đã đánh (0 = trống). Kiểm tra quân vừa đánh tại (row, col).</summary>
    public static bool IsWin(int[] board, int row, int col)
    {
        var who = board[row * Size + col];
        if (who == 0) return false;
        foreach (var (dr, dc) in Directions)
        {
            var count = 1 + Count(board, row, col, dr, dc, who) + Count(board, row, col, -dr, -dc, who);
            if (count >= WinLength) return true;
        }
        return false;
    }

    private static int Count(int[] board, int row, int col, int dr, int dc, int who)
    {
        var n = 0;
        for (int r = row + dr, c = col + dc;
             r is >= 0 and < Size && c is >= 0 and < Size && board[r * Size + c] == who;
             r += dr, c += dc) n++;
        return n;
    }
}

/// <summary>Luật trận đua giải cùng đề.</summary>
public static class RaceRules
{
    public const int FinishProgressGate = 90, TimeLimitMinutes = 15, MaxProgressPerSecond = 4;
    public const int ClockToleranceMs = 3000;

    /// <summary>
    /// Thời gian tối thiểu hợp lý (ms): Sudoku 30s; Xếp hình 3x3 5s / 4x4 20s / 5x5 40s (độ khó 1/2/3);
    /// Rubik 5s x độ khó (5/10/15s).
    /// </summary>
    public static int MinTimeMs(string gameCode, int difficulty)
    {
        var d = Math.Clamp(difficulty, 1, 3);
        return gameCode.ToUpperInvariant() switch
        {
            "SUDOKU" => 30_000,
            "PUZZLE" => new[] { 5_000, 20_000, 40_000 }[d - 1],
            "RUBIK" => 5_000 * d,
            _ => 5_000,
        };
    }
}
