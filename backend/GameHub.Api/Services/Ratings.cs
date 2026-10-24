namespace GameHub.Api.Services;

public record SeasonWindow(DateTime StartUtc, DateTime EndUtc);

/// <summary>Mùa = tuần lịch, bắt đầu 00:00 thứ Hai giờ Việt Nam (UTC+7, không có DST). Tính hoàn toàn trên UTC.</summary>
public static class Season
{
    public static readonly TimeSpan VnOffset = TimeSpan.FromHours(7);

    public static SeasonWindow Of(DateTime utcNow)
    {
        var local = DateTime.SpecifyKind(utcNow, DateTimeKind.Utc).Add(VnOffset);
        var daysSinceMonday = ((int)local.DayOfWeek + 6) % 7;
        var startLocal = local.Date.AddDays(-daysSinceMonday);
        var start = DateTime.SpecifyKind(startLocal - VnOffset, DateTimeKind.Utc);
        return new SeasonWindow(start, start.AddDays(7));
    }
}

public record Tier(string Code, string Name);

public static class Tiers
{
    public static readonly string[] Codes = ["BRONZE", "SILVER", "GOLD", "PLATINUM", "DIAMOND"];

    /// <summary>Đồng &lt; 1100 · Bạc &lt; 1250 · Vàng &lt; 1400 · Bạch kim &lt; 1600 · Kim cương ≥ 1600.</summary>
    public static Tier Of(int rating) => rating switch
    {
        < 1100 => new("BRONZE", "Đồng"),
        < 1250 => new("SILVER", "Bạc"),
        < 1400 => new("GOLD", "Vàng"),
        < 1600 => new("PLATINUM", "Bạch kim"),
        _ => new("DIAMOND", "Kim cương"),
    };
}

public static class Elo
{
    public const int StartRating = 1000, PlacementGames = 10, KPlacement = 40, KNormal = 24;

    public static int K(int gamesPlayed) => gamesPlayed < PlacementGames ? KPlacement : KNormal;

    public static double Expected(int rating, int opponent) => 1.0 / (1.0 + Math.Pow(10, (opponent - rating) / 400.0));

    /// <summary>score: 1 thắng, 0.5 hòa, 0 thua. Trả về rating mới (không âm).</summary>
    public static int NewRating(int rating, int opponentRating, double score, int gamesPlayed)
    {
        var delta = (int)Math.Round(K(gamesPlayed) * (score - Expected(rating, opponentRating)), MidpointRounding.AwayFromZero);
        return Math.Max(rating + delta, 0);
    }
}
