using GameHub.Api.model;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/users")]
public class UsersController(
    IUserRepository users,
    IFriendshipRepository friendships,
    GameHubDbContext db,
    PresenceService presence) : ApiControllerBase
{
    public static UserDto ToDto(User u) => new(u.UserId, u.Username, u.Email, u.FullName, u.AvatarUrl, u.CreatedAt);

    [HttpGet("me")]
    public async Task<ActionResult<UserDto>> Me(CancellationToken ct)
    {
        var id = CurrentUserId;
        var user = await users.Users().AsNoTracking().FirstOrDefaultAsync(u => u.UserId == id && u.IsActive, ct);
        return user is null ? Problem(statusCode: 401, title: "Tài khoản không tồn tại") : ToDto(user);
    }

    [HttpPut("me")]
    public async Task<ActionResult<UserDto>> UpdateMe(UpdateProfileRequest req, CancellationToken ct)
    {
        var id = CurrentUserId;
        var user = await users.Users().FirstOrDefaultAsync(u => u.UserId == id && u.IsActive, ct);
        if (user is null) return Problem(statusCode: 401, title: "Tài khoản không tồn tại");

        if (req.FullName is not null) user.FullName = string.IsNullOrWhiteSpace(req.FullName) ? null : req.FullName.Trim();
        if (req.AvatarUrl is not null) user.AvatarUrl = string.IsNullOrWhiteSpace(req.AvatarUrl) ? null : req.AvatarUrl.Trim();
        await users.SaveAsync(ct);
        return ToDto(user);
    }

    [HttpGet("search")]
    public async Task<ActionResult<List<UserSummaryDto>>> Search([FromQuery] string? q, CancellationToken ct)
    {
        q = q?.Trim();
        if (string.IsNullOrEmpty(q) || q.Length < 2)
            return Problem(statusCode: 400, title: "Từ khóa tìm kiếm phải có ít nhất 2 ký tự");

        var me = CurrentUserId;
        var result = await users.Users().AsNoTracking()
            .Where(u => u.IsActive && u.UserId != me
                        && (u.Username.Contains(q) || (u.FullName != null && u.FullName.Contains(q))))
            .OrderBy(u => u.Username)
            .Take(20)
            .Select(u => new UserSummaryDto(u.UserId, u.Username, u.FullName, u.AvatarUrl))
            .ToListAsync(ct);
        return result;
    }

    [HttpGet("{id:int}/profile")]
    public async Task<ActionResult<ProfileDto>> Profile(int id, CancellationToken ct)
    {
        var me = CurrentUserId;
        var u = await users.Users().AsNoTracking().FirstOrDefaultAsync(x => x.UserId == id && x.IsActive, ct);
        if (u is null) return Problem(statusCode: 404, title: "Không tìm thấy người chơi");

        var isFriend = false;
        var rel = "NONE";
        int? pendingId = null;
        if (id == me) rel = "SELF";
        else
        {
            var f = await friendships.FindPairAsync(me, id, ct);
            if (f?.Status == Friendship.Accepted) { isFriend = true; rel = "ACCEPTED"; }
            else if (f?.Status == Friendship.Pending)
            {
                rel = f.RequesterId == me ? "PENDING_SENT" : "PENDING_RECEIVED";
                pendingId = f.FriendshipId;
            }
        }
        var stats = await db.GameStatsAsync(id, ct);
        return new ProfileDto(new UserSummaryDto(u.UserId, u.Username, u.FullName, u.AvatarUrl), u.CreatedAt,
            isFriend, rel, pendingId, presence.StatusOf(id), presence.LastSeenInMemory(id) ?? u.LastSeenAt, stats);
    }
}
