using System.Security.Claims;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace GameHub.Api.Services;

public static class ClaimsExtensions
{
    // Token dùng claim "sub" (MapInboundClaims = false)
    public static int GetUserId(this ClaimsPrincipal user) =>
        int.Parse(user.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());
}

public class GlobalExceptionHandler(IProblemDetailsService problems, IHostEnvironment env, ILogger<GlobalExceptionHandler> log) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext ctx, Exception ex, CancellationToken ct)
    {
        log.LogError(ex, "Unhandled exception");
        ctx.Response.StatusCode = StatusCodes.Status500InternalServerError;
        return await problems.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = ctx,
            Exception = ex,
            ProblemDetails = new ProblemDetails
            {
                Status = 500,
                Title = "Lỗi máy chủ",
                Detail = env.IsDevelopment() ? ex.Message : "Đã có lỗi xảy ra, vui lòng thử lại sau.",
            },
        });
    }
}
