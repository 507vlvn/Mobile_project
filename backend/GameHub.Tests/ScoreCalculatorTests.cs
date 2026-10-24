using GameHub.Api.Services;
using Xunit;

namespace GameHub.Tests;

public class ScoreCalculatorTests
{
    [Theory]
    // đúng par -> base
    [InlineData(1, 360, 0, "COMPLETED", "SUDOKU", 0, 1000)]
    [InlineData(2, 240, 0, "COMPLETED", "PUZZLE", 0, 2000)]
    [InlineData(3, 600, 0, "COMPLETED", "RUBIK", 0, 3000)]
    // nhanh gấp đôi -> trần 1.5
    [InlineData(1, 180, 0, "COMPLETED", "SUDOKU", 0, 1500)]
    [InlineData(2, 10, 0, "COMPLETED", "RUBIK", 0, 3000)]
    // rất chậm -> sàn 0.25
    [InlineData(1, 3600, 0, "COMPLETED", "SUDOKU", 0, 250)]
    [InlineData(3, 100000, 0, "COMPLETED", "RUBIK", 0, 750)]
    // chậm vừa: par/time
    [InlineData(1, 720, 0, "COMPLETED", "SUDOKU", 0, 500)]
    // lỗi: 0.92^n
    [InlineData(1, 360, 2, "COMPLETED", "SUDOKU", 0, 846)]
    [InlineData(2, 240, 1, "COMPLETED", "PUZZLE", 0, 1840)]
    // Caro theo số nước (par 20/30/45)
    [InlineData(1, 5, 0, "WIN", "CARO", 20, 1000)]
    [InlineData(2, 5, 0, "WIN", "CARO", 15, 3000)]
    [InlineData(2, 5, 0, "WIN", "CARO", 300, 500)]
    [InlineData(3, 999, 0, "WIN", "CARO", 45, 3000)]
    [InlineData(2, 5, 0, "DRAW", "CARO", 30, 600)]
    // thua / bỏ cuộc = 0
    [InlineData(1, 50, 0, "LOSE", "CARO", 10, 0)]
    [InlineData(2, 50, 0, "ABANDONED", "SUDOKU", 0, 0)]
    public void Calculate_ReturnsExpected(int diff, int time, int mistakes, string result, string game, int moves, int expected)
        => Assert.Equal(expected, ScoreCalculator.Calculate(diff, time, mistakes, result, game, moves));

    [Fact]
    public void Par_Table_MatchesDesign()
    {
        Assert.Equal(360, ScoreCalculator.ParSeconds("SUDOKU", 1));
        Assert.Equal(1500, ScoreCalculator.ParSeconds("SUDOKU", 3));
        Assert.Equal(60, ScoreCalculator.ParSeconds("PUZZLE", 1));
        Assert.Equal(90, ScoreCalculator.ParSeconds("RUBIK", 1));
        Assert.Equal(600, ScoreCalculator.ParSeconds("RUBIK", 3));
        Assert.Equal(45, ScoreCalculator.ParMoves(3));
    }
}
