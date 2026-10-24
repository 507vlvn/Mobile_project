using GameHub.Api.model;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/social")]
public class SocialController(IMessageRepository messages, IChallengeRepository challenges) : ApiControllerBase
{
    /// <summary>Số liệu cho huy hiệu ở thanh điều hướng — 3 phép đếm nhẹ.</summary>
    [HttpGet("summary")]
    public async Task<ActionResult<SocialSummaryDto>> Summary(CancellationToken ct)
    {
        var me = CurrentUserId;
        var cutoff = ChallengeRules.ExpiryCutoff(DateTime.UtcNow);
        var unread = await messages.Messages().AsNoTracking().CountAsync(m => m.ReceiverId == me && !m.IsRead, ct);
        var incoming = await challenges.Challenges().AsNoTracking().CountAsync(c =>
            c.OpponentId == me && c.Status == ChallengeRules.Pending && c.CreatedAt > cutoff, ct);
        var active = await challenges.Challenges().AsNoTracking().CountAsync(c =>
            c.Status == ChallengeRules.Accepted && (c.ChallengerId == me || c.OpponentId == me), ct);
        return new SocialSummaryDto(unread, incoming, active);
    }
}
