using GameHub.Api.model;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Services;

public record BoardQuery(string GameCode, string Board, int? Difficulty, string Scope, string Period)
{
    public bool IsRanked => Board == "ranked";
    public bool IsFriends => Scope == "friends";
    public bool IsSeason => Period == "season";
}

public class LeaderboardService(GameHubDbContext db)
{
    private static readonly string[] Scoring = ["COMPLETED", "WIN"];

    /// <summary>Danh sách user được phép xuất hiện (null = toàn server). Phạm vi bạn bè luôn gồm chính mình.</summary>
    private async Task<List<int>?> ScopeUsersAsync(BoardQuery q, int? me, CancellationToken ct)
    {
        if (!q.IsFriends) return null;
        if (me is null) throw new UnauthorizedAccessException();
        var ids = await db.FriendIdsAsync(me.Value, ct);
        ids.Add(me.Value);
        return ids;
    }

    private async Task<(List<RecordRow> Rows, int[] Ranks)> RecordBoardAsync(BoardQuery q, int? me, CancellationToken ct)
    {
        var scope = await ScopeUsersAsync(q, me, ct);
        var runs = db.History.AsNoTracking()
            .Where(h => Scoring.Contains(h.Result) && h.Score > 0 && h.MatchId == null && h.Game.GameCode == q.GameCode && h.User.IsActive);
        if (q.Difficulty is int d) runs = runs.Where(h => h.Level!.Difficulty == d);
        if (q.IsSeason)
        {
            var s = Season.Of(DateTime.UtcNow);
            runs = runs.Where(h => h.PlayedAt >= s.StartUtc && h.PlayedAt < s.EndUtc);
        }
        if (scope is not null) runs = runs.Where(h => scope.Contains(h.UserId));

        var rows = await runs.Select(h => new RunRow(h.UserId, h.Score, h.TimeSpentSeconds, h.PlayedAt)).ToListAsync(ct);
        var board = LeaderboardRules.BuildRecordBoard(rows);
        return (board, LeaderboardRules.RanksOf(board));
    }

    private async Task<(List<RatingRow> Rows, int[] Ranks, Dictionary<int, PlayerRating> Details)> RatingBoardAsync(
        BoardQuery q, int? me, CancellationToken ct)
    {
        var scope = await ScopeUsersAsync(q, me, ct);
        var gameId = await db.Games.AsNoTracking().Where(g => g.GameCode == q.GameCode).Select(g => (int?)g.GameId).FirstOrDefaultAsync(ct);
        if (gameId is null) return ([], [], []);

        var ratings = db.PlayerRatings.AsNoTracking()
            .Where(r => r.GameId == gameId && r.Games > 0 && db.Users.Any(u => u.UserId == r.UserId && u.IsActive));
        if (scope is not null) ratings = ratings.Where(r => scope.Contains(r.UserId));
        if (q.IsSeason)
        {
            var s = Season.Of(DateTime.UtcNow);
            var m = db.Matches.AsNoTracking().Where(x => x.GameId == gameId && x.Mode == "RANKED"
                                                          && x.EndedAt >= s.StartUtc && x.EndedAt < s.EndUtc);
            var active = m.Select(x => x.Player1Id).Union(m.Select(x => x.Player2Id));
            ratings = ratings.Where(r => active.Contains(r.UserId));
        }

        var list = await ratings.ToListAsync(ct);
        var rows = LeaderboardRules.OrderRatings(list.Select(r => new RatingRow(r.UserId, r.Rating, r.Wins, r.UpdatedAt)));
        return (rows, LeaderboardRules.RanksOf(rows), list.ToDictionary(r => r.UserId));
    }

    public async Task<List<LeaderboardEntryDto>> TopAsync(BoardQuery q, int? me, int top, CancellationToken ct)
    {
        if (q.IsRanked)
        {
            var (rows, ranks, details) = await RatingBoardAsync(q, me, ct);
            var take = rows.Take(top).ToList();
            var users = await LoadUsersAsync(take.Select(r => r.UserId), ct);
            return take.Select((r, i) =>
            {
                var u = users[r.UserId];
                var t = Tiers.Of(r.Rating);
                return new LeaderboardEntryDto(ranks[i], r.UserId, u.Username, u.FullName, u.AvatarUrl, r.Rating, 0,
                    r.Rating, t.Code, t.Name, details[r.UserId].Games, r.Wins);
            }).ToList();
        }
        else
        {
            var (rows, ranks) = await RecordBoardAsync(q, me, ct);
            var take = rows.Take(top).ToList();
            var users = await LoadUsersAsync(take.Select(r => r.UserId), ct);
            return take.Select((r, i) =>
            {
                var u = users[r.UserId];
                return new LeaderboardEntryDto(ranks[i], r.UserId, u.Username, u.FullName, u.AvatarUrl, r.Score, r.TimeSeconds);
            }).ToList();
        }
    }

    public async Task<MyRankDto> MyRankAsync(BoardQuery q, int me, CancellationToken ct)
    {
        if (q.IsRanked)
        {
            var (rows, ranks, details) = await RatingBoardAsync(q, me, ct);
            var i = rows.FindIndex(r => r.UserId == me);
            if (i < 0) return new MyRankDto(null, null, null);
            var r = rows[i];
            var t = Tiers.Of(r.Rating);
            return new MyRankDto(ranks[i], r.Rating, 0, r.Rating, t.Code, t.Name, details[me].Games, r.Wins);
        }
        else
        {
            var (rows, ranks) = await RecordBoardAsync(q, me, ct);
            var i = rows.FindIndex(r => r.UserId == me);
            return i < 0 ? new MyRankDto(null, null, null) : new MyRankDto(ranks[i], rows[i].Score, rows[i].TimeSeconds);
        }
    }

    private async Task<Dictionary<int, User>> LoadUsersAsync(IEnumerable<int> ids, CancellationToken ct)
    {
        var list = ids.ToList();
        if (list.Count == 0) return [];
        return await db.Users.AsNoTracking().Where(u => list.Contains(u.UserId)).ToDictionaryAsync(u => u.UserId, ct);
    }
}
