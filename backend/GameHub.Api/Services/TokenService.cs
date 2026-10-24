using System.Security.Claims;
using System.Text;
using GameHub.Api.model;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace GameHub.Api.Services;

public class JwtOptions
{
    public string Key { get; set; } = "";
    public string Issuer { get; set; } = "GameHub";
    public string Audience { get; set; } = "GameHubClients";
    public int LifetimeDays { get; set; } = 7;
}

public interface ITokenService { string CreateToken(User user); }

public class TokenService(IOptions<JwtOptions> options) : ITokenService
{
    private readonly JwtOptions _o = options.Value;

    public string CreateToken(User user)
    {
        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = _o.Issuer,
            Audience = _o.Audience,
            Expires = DateTime.UtcNow.AddDays(_o.LifetimeDays),
            Subject = new ClaimsIdentity([
                new Claim(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
                new Claim(JwtRegisteredClaimNames.UniqueName, user.Username),
            ]),
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_o.Key)), SecurityAlgorithms.HmacSha256),
        };
        return new JsonWebTokenHandler().CreateToken(descriptor);
    }
}
