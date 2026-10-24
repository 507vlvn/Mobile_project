namespace GameHub.Api.Services;

public record RunRow(int UserId, int Score, int TimeSeconds, DateTime PlayedAt);
public record RecordRow(int UserId, int Score, int TimeSeconds, DateTime PlayedAt);
public record RatingRow(int UserId, int Rating, int Wins, DateTime UpdatedAt);

/// <summary>Logic thuần (không DB) để xếp hạng: kết quả giống nhau cho danh sách và "Hạng của bạn".</summary>
public static class LeaderboardRules
{
    /// <summary>Mỗi người một dòng tốt nhất: điểm cao nhất, rồi thời gian ngắn hơn, rồi đạt sớm hơn. Trả về đã sắp xếp.</summary>
    public static List<RecordRow> BuildRecordBoard(IEnumerable<RunRow> runs) =>
        runs.GroupBy(r => r.UserId)
            .Select(g => g.OrderByDescending(r => r.Score).ThenBy(r => r.TimeSeconds).ThenBy(r => r.PlayedAt).First())
            .Select(r => new RecordRow(r.UserId, r.Score, r.TimeSeconds, r.PlayedAt))
            .OrderByDescending(r => r.Score).ThenBy(r => r.TimeSeconds).ThenBy(r => r.PlayedAt).ThenBy(r => r.UserId)
            .ToList();

    public static List<RatingRow> OrderRatings(IEnumerable<RatingRow> rows) =>
        rows.OrderByDescending(r => r.Rating).ThenByDescending(r => r.Wins).ThenBy(r => r.UpdatedAt).ThenBy(r => r.UserId).ToList();

    /// <summary>Đánh hạng kiểu thi đấu (1, 2, 2, 4): khóa bằng nhau thì cùng hạng. Đầu vào đã sắp xếp.</summary>
    public static int[] CompetitionRanks<TKey>(IReadOnlyList<TKey> orderedKeys)
    {
        var ranks = new int[orderedKeys.Count];
        for (var i = 0; i < ranks.Length; i++)
            ranks[i] = i > 0 && EqualityComparer<TKey>.Default.Equals(orderedKeys[i], orderedKeys[i - 1]) ? ranks[i - 1] : i + 1;
        return ranks;
    }

    public static (int Score, int Time, DateTime At) Key(RecordRow r) => (r.Score, r.TimeSeconds, r.PlayedAt);
    public static (int Rating, int Wins, DateTime At) Key(RatingRow r) => (r.Rating, r.Wins, r.UpdatedAt);

    public static int[] RanksOf(IReadOnlyList<RecordRow> sorted) => CompetitionRanks(sorted.Select(Key).ToList());
    public static int[] RanksOf(IReadOnlyList<RatingRow> sorted) => CompetitionRanks(sorted.Select(Key).ToList());
}
