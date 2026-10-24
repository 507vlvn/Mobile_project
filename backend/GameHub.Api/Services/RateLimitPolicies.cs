using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

namespace GameHub.Api.Services;

/// <summary>Giới hạn theo người dùng (claim "sub") để bảo vệ DB host miễn phí.</summary>
public static class RateLimitPolicies
{
    public const string SendMessage = "send-message";
    public const string CreateChallenge = "create-challenge";

    public const int MessagesPerMinute = 20;
    public const int ChallengesPerHour = 10;

    public static string PartitionKey(HttpContext ctx) =>
        ctx.User.FindFirst("sub")?.Value ?? ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    public static void AddUserPolicies(RateLimiterOptions o)
    {
        o.AddPolicy(SendMessage, ctx => RateLimitPartition.GetFixedWindowLimiter(PartitionKey(ctx),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = MessagesPerMinute, Window = TimeSpan.FromMinutes(1), QueueLimit = 0,
            }));
        o.AddPolicy(CreateChallenge, ctx => RateLimitPartition.GetFixedWindowLimiter(PartitionKey(ctx),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = ChallengesPerHour, Window = TimeSpan.FromHours(1), QueueLimit = 0,
            }));
    }
}
