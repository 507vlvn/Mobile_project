using GameHub.Api.Services;

namespace GameHub.Tests;

public class ChallengeRulesTests
{
    [Theory]
    [InlineData(1500, 100, 1200, 50, 1)]   // điểm cao hơn thắng dù chậm hơn
    [InlineData(1000, 100, 1200, 50, 2)]
    [InlineData(1000, 60, 1000, 90, 1)]    // bằng điểm: thời gian ngắn hơn thắng
    [InlineData(1000, 90, 1000, 60, 2)]
    public void DecideWinner_PicksExpected(int sa, int ta, int sb, int tb, int expected)
        => Assert.Equal(expected, ChallengeRules.DecideWinner(1, sa, ta, 2, sb, tb));

    [Fact]
    public void DecideWinner_SameScoreAndTime_IsDraw()
        => Assert.Null(ChallengeRules.DecideWinner(1, 800, 70, 2, 800, 70));

    [Fact]
    public void DecideWinner_BothZero_IsDraw()
        => Assert.Null(ChallengeRules.DecideWinner(1, 0, 10, 2, 0, 99));

    [Fact]
    public void DecideWinner_ZeroLosesToAnyScore()
        => Assert.Equal(2, ChallengeRules.DecideWinner(1, 0, 5, 2, 300, 900));

    [Fact]
    public void IsExpired_OnlyPendingOlderThan7Days()
    {
        var now = new DateTime(2026, 10, 14, 0, 0, 0, DateTimeKind.Utc);
        Assert.True(ChallengeRules.IsExpired("PENDING", now.AddDays(-7), now));
        Assert.True(ChallengeRules.IsExpired("PENDING", now.AddDays(-30), now));
        Assert.False(ChallengeRules.IsExpired("PENDING", now.AddDays(-6), now));
        Assert.False(ChallengeRules.IsExpired("ACCEPTED", now.AddDays(-30), now));
    }

    [Theory]
    [InlineData("incoming", true, ChallengeBox.Incoming)]
    [InlineData(" Outgoing ", true, ChallengeBox.Outgoing)]
    [InlineData("ACTIVE", true, ChallengeBox.Active)]
    [InlineData("done", true, ChallengeBox.Done)]
    [InlineData("all", true, ChallengeBox.All)]
    [InlineData("other", false, default(ChallengeBox))]
    [InlineData(null, false, default(ChallengeBox))]
    public void TryParseBox_Works(string? value, bool ok, ChallengeBox expected)
    {
        Assert.Equal(ok, ChallengeRules.TryParseBox(value, out var box));
        Assert.Equal(expected, box);
    }

    [Theory]
    [InlineData("  xin chào  ", true, "xin chào")]
    [InlineData("", false, "")]
    [InlineData("   ", false, "")]
    [InlineData(null, false, "")]
    public void TryNormalizeMessage_TrimsAndRejectsEmpty(string? input, bool ok, string expected)
    {
        Assert.Equal(ok, ChallengeRules.TryNormalizeMessage(input, out var n, out var err));
        Assert.Equal(expected, n);
        Assert.Equal(!ok, err is not null);
    }

    [Fact]
    public void TryNormalizeMessage_LengthLimit()
    {
        Assert.True(ChallengeRules.TryNormalizeMessage(new string('a', 1000), out _, out _));
        Assert.False(ChallengeRules.TryNormalizeMessage(new string('a', 1001), out _, out var err));
        Assert.NotNull(err);
        // khoảng trắng hai đầu không tính vào giới hạn
        Assert.True(ChallengeRules.TryNormalizeMessage(" " + new string('a', 1000) + " ", out _, out _));
    }

    [Theory]
    [InlineData(null, 30)]
    [InlineData(0, 1)]
    [InlineData(-5, 1)]
    [InlineData(50, 50)]
    [InlineData(5000, 100)]
    public void ClampLimit_Works(int? input, int expected)
        => Assert.Equal(expected, ChallengeRules.ClampLimit(input));
}
