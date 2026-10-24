using GameHub.Api.Services;
using Xunit;

namespace GameHub.Tests;

public class RankingTests
{
    private static readonly DateTime T0 = new(2026, 10, 20, 0, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void CompetitionRanks_AreOneTwoTwoFour()
    {
        var ranks = LeaderboardRules.CompetitionRanks(new[] { 10, 8, 8, 5, 5, 1 });
        Assert.Equal(new[] { 1, 2, 2, 4, 4, 6 }, ranks);
    }

    [Fact]
    public void RecordBoard_OneRowPerUser_BestScoreThenLowerTimeThenEarlier()
    {
        var runs = new[]
        {
            new RunRow(1, 500, 100, T0), new RunRow(1, 900, 200, T0.AddHours(1)),      // user1 best 900
            new RunRow(2, 900, 150, T0.AddHours(2)),                                   // thời gian ngắn hơn -> trên user1
            new RunRow(3, 900, 150, T0.AddHours(1)),                                   // bằng điểm+thời gian, sớm hơn -> trên user2
            new RunRow(4, 100, 10, T0),
        };
        var board = LeaderboardRules.BuildRecordBoard(runs);
        Assert.Equal(new[] { 3, 2, 1, 4 }, board.Select(b => b.UserId));
    }

    [Fact]
    public void RecordBoard_RanksShareSameForListAndMe_WhenFullyTied()
    {
        var runs = new[] { new RunRow(1, 900, 100, T0), new RunRow(2, 900, 100, T0), new RunRow(3, 800, 100, T0) };
        var board = LeaderboardRules.BuildRecordBoard(runs);
        var ranks = LeaderboardRules.RanksOf(board);
        Assert.Equal(new[] { 1, 1, 3 }, ranks);
    }

    [Fact]
    public void RatingBoard_TieBreak_MoreWinsThenEarlierUpdate()
    {
        var rows = LeaderboardRules.OrderRatings(new[]
        {
            new RatingRow(1, 1200, 5, T0.AddHours(3)),
            new RatingRow(2, 1200, 9, T0.AddHours(5)),
            new RatingRow(3, 1200, 9, T0.AddHours(1)),
            new RatingRow(4, 1300, 0, T0),
        });
        Assert.Equal(new[] { 4, 3, 2, 1 }, rows.Select(r => r.UserId));
        Assert.Equal(new[] { 1, 2, 3, 4 }, LeaderboardRules.RanksOf(rows));
    }

    [Fact]
    public void RatingBoard_EqualAll_SameRank()
    {
        var rows = LeaderboardRules.OrderRatings(new[] { new RatingRow(1, 1100, 3, T0), new RatingRow(2, 1100, 3, T0) });
        Assert.Equal(new[] { 1, 1 }, LeaderboardRules.RanksOf(rows));
    }
}

public class SeasonTests
{
    [Fact]
    public void Season_StartsMondayMidnightVietnam()
    {
        // 24/10/2026 là thứ Bảy. Thứ Hai 19/10 00:00 VN = 18/10 17:00 UTC
        var s = Season.Of(new DateTime(2026, 10, 24, 12, 0, 0, DateTimeKind.Utc));
        Assert.Equal(new DateTime(2026, 10, 18, 17, 0, 0, DateTimeKind.Utc), s.StartUtc);
        Assert.Equal(new DateTime(2026, 10, 25, 17, 0, 0, DateTimeKind.Utc), s.EndUtc);
    }

    [Fact]
    public void Season_Boundary_JustBeforeAndAtMondayMidnight()
    {
        var before = Season.Of(new DateTime(2026, 10, 25, 16, 59, 59, DateTimeKind.Utc)); // Chủ nhật 23:59:59 VN
        var at = Season.Of(new DateTime(2026, 10, 25, 17, 0, 0, DateTimeKind.Utc));       // Thứ Hai 00:00:00 VN
        Assert.Equal(new DateTime(2026, 10, 18, 17, 0, 0, DateTimeKind.Utc), before.StartUtc);
        Assert.Equal(new DateTime(2026, 10, 25, 17, 0, 0, DateTimeKind.Utc), at.StartUtc);
        Assert.Equal(before.EndUtc, at.StartUtc);
    }

    [Fact]
    public void Season_SundayUtcEvening_IsAlreadyMondayInVietnam()
    {
        var s = Season.Of(new DateTime(2026, 10, 25, 20, 0, 0, DateTimeKind.Utc)); // 03:00 thứ Hai VN
        Assert.Equal(new DateTime(2026, 10, 25, 17, 0, 0, DateTimeKind.Utc), s.StartUtc);
    }
}

public class EloTests
{
    [Fact]
    public void Equal_Players_FirstGames_K40()
    {
        Assert.Equal(1020, Elo.NewRating(1000, 1000, 1, 0));
        Assert.Equal(980, Elo.NewRating(1000, 1000, 0, 0));
        Assert.Equal(1000, Elo.NewRating(1000, 1000, 0.5, 0));
    }

    [Fact]
    public void K_Drops_To24_After10Games()
    {
        Assert.Equal(40, Elo.K(9));
        Assert.Equal(24, Elo.K(10));
        Assert.Equal(1012, Elo.NewRating(1000, 1000, 1, 10));
    }

    [Fact]
    public void Upset_GivesMore_AndRatingNeverNegative()
    {
        var upset = Elo.NewRating(1000, 1400, 1, 0) - 1000;
        var expectedWin = Elo.NewRating(1400, 1000, 1, 0) - 1400;
        Assert.True(upset > expectedWin);
        Assert.True(Elo.NewRating(0, 2000, 0, 0) >= 0);
    }

    [Theory]
    [InlineData(1000, "BRONZE")]
    [InlineData(1099, "BRONZE")]
    [InlineData(1100, "SILVER")]
    [InlineData(1249, "SILVER")]
    [InlineData(1250, "GOLD")]
    [InlineData(1399, "GOLD")]
    [InlineData(1400, "PLATINUM")]
    [InlineData(1599, "PLATINUM")]
    [InlineData(1600, "DIAMOND")]
    public void Tiers_Thresholds(int rating, string code) => Assert.Equal(code, Tiers.Of(rating).Code);

    [Fact]
    public void Tier_Names_Vietnamese()
    {
        Assert.Equal("Đồng", Tiers.Of(900).Name);
        Assert.Equal("Bạc", Tiers.Of(1100).Name);
        Assert.Equal("Vàng", Tiers.Of(1250).Name);
        Assert.Equal("Bạch kim", Tiers.Of(1400).Name);
        Assert.Equal("Kim cương", Tiers.Of(1700).Name);
    }
}
