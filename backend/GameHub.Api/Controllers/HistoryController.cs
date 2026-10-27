using GameHub.Api.model;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/history")]
public class HistoryController(
    IHistoryRepository history,
    IGameRepository games,
    IChallengeRepository challenges,
    ChallengeService challengeSvc) : ApiControllerBase
{
    private static readonly string[] Scoring = ["COMPLETED", "WIN"];

    [HttpPost]
    public async Task<ActionResult<SubmitHistoryResponse>> Submit(SubmitHistoryRequest req, CancellationToken ct)
    {
        var userId = CurrentUserId;
        var gameCode = req.GameCode.Trim().ToUpperInvariant();
        var result = req.Result.Trim().ToUpperInvariant();

        if (!ScoreCalculator.ValidResults.Contains(result))
            return Problem(statusCode: 400, title: "Kết quả không hợp lệ");

        var game = await games.FindByCodeAsync(gameCode, ct);
        if (game is null) return Problem(statusCode: 400, title: "Game không tồn tại");

        var level = await games.FindDefaultLevelAsync(game.GameId, req.Difficulty, ct);
        if (level is null) return Problem(statusCode: 400, title: "Độ khó không tồn tại cho game này");

        Challenge? challenge = null;
        if (req.ChallengeId is int cid)
        {
            challenge = await challenges.FindByIdAsync(cid, ct);
            if (challenge is null || (challenge.ChallengerId != userId && challenge.OpponentId != userId)
                || challenge.GameId != game.GameId || challenge.LevelId != level.LevelId)
                return Problem(statusCode: 400, title: "Thách đấu không hợp lệ");
            if (challenge.Status != ChallengeRules.Accepted)
                return Problem(statusCode: 409, title: "Thách đấu chưa được chấp nhận hoặc đã kết thúc");
            if (await history.History().AnyAsync(h => h.ChallengeId == cid && h.UserId == userId, ct))
                return Problem(statusCode: 409, title: "Bạn đã nộp kết quả cho thách đấu này");
        }

        var score = ScoreCalculator.Calculate(req.Difficulty, req.TimeSpentSeconds, req.MistakesCount, result, gameCode,
            req.MovesCount, req.HintsUsed);

        var isBest = false;
        if (Scoring.Contains(result))
        {
            var prevBest = await history.GetPersonalBestScoreAsync(userId, game.GameId, req.Difficulty, ct);
            isBest = prevBest is null || score > prevBest;
        }

        var entry = new HistoryEntry
        {
            UserId = userId,
            GameId = game.GameId,
            LevelId = level.LevelId,
            ChallengeId = req.ChallengeId,
            TimeSpentSeconds = req.TimeSpentSeconds,
            MistakesCount = req.MistakesCount,
            MovesCount = req.MovesCount,
            HintsUsed = req.HintsUsed,
            Result = result,
            Score = score,
            PlayedAt = DateTime.UtcNow,
        };
        history.Add(entry);
        try
        {
            await history.SaveChangesAsync(ct);
        }
        catch (DbUpdateException) when (challenge is not null)
        {
            // Chỉ mục duy nhất (challenge_id, user_id): nộp trùng do hai request đồng thời.
            return Problem(statusCode: 409, title: "Bạn đã nộp kết quả cho thách đấu này");
        }

        ChallengeDto? challengeDto = null;
        if (challenge is not null)
        {
            var other = await history.History().AsNoTracking()
                .FirstOrDefaultAsync(h => h.ChallengeId == challenge.ChallengeId && h.UserId != userId, ct);
            if (other is not null)
            {
                challenge.WinnerId = ChallengeRules.DecideWinner(
                    userId, entry.Score, entry.TimeSpentSeconds, other.UserId, other.Score, other.TimeSpentSeconds);
                challenge.Status = ChallengeRules.Completed;
                challenge.CompletedAt = DateTime.UtcNow;
                await challenges.SaveChangesAsync(ct);
            }
            challengeDto = await challengeSvc.GetDtoAsync(challenge.ChallengeId, userId, ct);
        }

        var dto = new HistoryDto(entry.HistoryId, game.GameCode, game.GameName, level.Difficulty, level.DifficultyName,
            entry.TimeSpentSeconds, entry.MistakesCount, entry.MovesCount, entry.HintsUsed,
            entry.Result, entry.Score, entry.ChallengeId, entry.PlayedAt);
        return Ok(new SubmitHistoryResponse(dto, isBest, challengeDto));
    }

    [HttpGet("me")]
    public async Task<ActionResult<PagedResult<HistoryDto>>> Mine(
        [FromQuery] string? gameCode, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var userId = CurrentUserId;

        var q = history.History().AsNoTracking().Where(h => h.UserId == userId);
        if (!string.IsNullOrWhiteSpace(gameCode))
        {
            var code = gameCode.Trim().ToUpperInvariant();
            q = q.Where(h => h.Game.GameCode == code);
        }

        var total = await q.CountAsync(ct);
        var items = await q.OrderByDescending(h => h.PlayedAt).ThenByDescending(h => h.HistoryId)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(h => new HistoryDto(h.HistoryId, h.Game.GameCode, h.Game.GameName,
                h.Level != null ? h.Level.Difficulty : null, h.Level != null ? h.Level.DifficultyName : null,
                h.TimeSpentSeconds, h.MistakesCount, h.MovesCount, h.HintsUsed,
                h.Result, h.Score, h.ChallengeId, h.PlayedAt))
            .ToListAsync(ct);
        return new PagedResult<HistoryDto>(items, page, pageSize, total);
    }
}
