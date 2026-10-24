using GameHub.Api.model;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Controllers;

[ApiController]
[Route("api/auth")]
[EnableRateLimiting("auth")]
public class AuthController(IUserRepository users, ITokenService tokens) : ApiControllerBase
{
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest req, CancellationToken ct)
    {
        var username = req.Username.Trim();
        var email = req.Email.Trim().ToLowerInvariant();

        if (await users.Users().AnyAsync(u => u.Username == username, ct))
            return Problem(statusCode: 409, title: "Tên đăng nhập đã tồn tại");
        if (await users.Users().AnyAsync(u => u.Email == email, ct))
            return Problem(statusCode: 409, title: "Email đã được sử dụng");

        var user = new User
        {
            Username = username,
            Email = email,
            FullName = string.IsNullOrWhiteSpace(req.FullName) ? null : req.FullName.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
        };
        users.Add(user);

        if (!await users.SaveAsync(ct))
        {
            return Problem(statusCode: 409, title: "Tên đăng nhập hoặc email đã tồn tại");
        }
        return Ok(new AuthResponse(tokens.CreateToken(user), UsersController.ToDto(user)));
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest req, CancellationToken ct)
    {
        var user = await users.FindByUsernameOrEmailAsync(req.UsernameOrEmail, ct);

        if (user is null || !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
            return Problem(statusCode: 401, title: "Sai tên đăng nhập hoặc mật khẩu");

        return Ok(new AuthResponse(tokens.CreateToken(user), UsersController.ToDto(user)));
    }
}
