using GameHub.Api.model;
using GameHub.Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Services;

/// <summary>Dựng ChallengeDto (gồm kết quả hai bên) với số truy vấn cố định, không N+1.</summary>
public class ChallengeService(IChallengeRepository challengeRepo, IHistoryRepository historyRepo, GameHubDbContext db)
{
    public IQueryable<Challenge> Full() => challengeRepo.Challenges().AsNoTracking()
        .Include(c => c.Challenger).Include(c => c.Opponent).Include(c => c.Game).Include(c => c.Level);

    public async Task<List<ChallengeDto>> ToDtosAsync(List<Challenge> list, int me, CancellationToken ct)
    {
        if (list.Count == 0) return [];
        var ids = list.Select(c => c.ChallengeId).ToList();
        var rows = await historyRepo.History().AsNoTracking()
            .Where(h => h.ChallengeId != null && ids.Contains(h.ChallengeId.Value))
            .ToListAsync(ct);
        var byKey = rows.ToDictionary(h => (h.ChallengeId!.Value, h.UserId));

        return list.Select(c =>
        {
            byKey.TryGetValue((c.ChallengeId, me), out var mine);
            var otherId = c.ChallengerId == me ? c.OpponentId : c.ChallengerId;
            byKey.TryGetValue((c.ChallengeId, otherId), out var theirs);
            // Chỉ lộ kết quả đối thủ khi mình đã nộp bài (tránh biết trước điểm cần vượt).
            var theirDto = mine is null && c.Status != ChallengeRules.Completed ? null : ToResult(theirs);
            return new ChallengeDto(
                c.ChallengeId, c.Game.GameCode, c.Game.GameName, c.Level?.Difficulty ?? 0, c.Status,
                c.CreatedAt, c.AcceptedAt, c.CompletedAt,
                new ChallengeUserDto(c.Challenger.UserId, c.Challenger.Username, c.Challenger.FullName),
                new ChallengeUserDto(c.Opponent.UserId, c.Opponent.Username, c.Opponent.FullName),
                ToResult(mine), theirDto, c.WinnerId, c.ChallengeId);
        }).ToList();
    }

    public async Task<ChallengeDto?> GetDtoAsync(int id, int me, CancellationToken ct)
    {
        var c = await Full().FirstOrDefaultAsync(x => x.ChallengeId == id, ct);
        if (c is null) return null;
        return (await ToDtosAsync([c], me, ct))[0];
    }

    private static ChallengeResultDto? ToResult(HistoryEntry? h) =>
        h is null ? null : new ChallengeResultDto(h.Score, h.TimeSpentSeconds, h.MistakesCount, h.Result);

    /// <summary>Đánh dấu hết hạn các lời thách PENDING quá 7 ngày của người dùng (1 lệnh UPDATE).</summary>
    public Task<int> ExpireStaleAsync(int me, DateTime utcNow, CancellationToken ct)
    {
        var cutoff = ChallengeRules.ExpiryCutoff(utcNow);
        return db.Challenges
            .Where(c => c.Status == ChallengeRules.Pending && c.CreatedAt <= cutoff
                        && (c.ChallengerId == me || c.OpponentId == me))
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.Status, ChallengeRules.Expired), ct);
    }
}
