using System.Text;
using System.Threading.RateLimiting;
using GameHub.Api.model;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;

// Nạp khoá bí mật từ file .env (không commit, xem .env.example) thành biến môi trường,
// để không phải ghi chuỗi kết nối / khoá JWT vào appsettings. Biến môi trường thật được ưu tiên.
DotEnv.Load(Path.Combine(Directory.GetCurrentDirectory(), ".env"));
DotEnv.Load(Path.Combine(AppContext.BaseDirectory, ".env"));

var builder = WebApplication.CreateBuilder(args);

// --- Options & DB ---
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));
var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (jwt.Key.Length < 32) throw new InvalidOperationException("Jwt:Key phải có ít nhất 32 ký tự.");

builder.Services.AddDbContext<GameHubDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// --- Repositories ---
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IGameRepository, GameRepository>();
builder.Services.AddScoped<IFriendshipRepository, FriendshipRepository>();
builder.Services.AddScoped<IChallengeRepository, ChallengeRepository>();
builder.Services.AddScoped<IMessageRepository, MessageRepository>();
builder.Services.AddScoped<IHistoryRepository, HistoryRepository>();
builder.Services.AddScoped<IMatchRepository, MatchRepository>();

// --- Services ---
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<LeaderboardService>();
builder.Services.AddScoped<ChallengeService>();

// --- Realtime (SignalR, trạng thái trận trong bộ nhớ) ---
builder.Services.AddSignalR();
builder.Services.AddSingleton<Microsoft.AspNetCore.SignalR.IUserIdProvider, SubUserIdProvider>();
builder.Services.AddSingleton<IClock, SystemClock>();
builder.Services.AddSingleton<ConnectionTracker>();
builder.Services.AddSingleton<IPresence>(sp => sp.GetRequiredService<ConnectionTracker>());
builder.Services.AddSingleton<IRealtimeNotifier, SignalRNotifier>();
builder.Services.AddSingleton<IMatchData, EfMatchData>();
builder.Services.AddSingleton<MatchService>();
builder.Services.AddSingleton<PresenceService>();
builder.Services.AddHostedService<MatchTicker>();

// --- Auth ---
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        // SignalR (WebSocket/SSE không gửi được header) gửi JWT qua query access_token
        o.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) && ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                    ctx.Token = token;
                return Task.CompletedTask;
            },
        };
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });
builder.Services.AddAuthorization();

// --- MVC, ProblemDetails (validation lỗi -> 400 ProblemDetails mặc định) ---
builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();

// --- CORS ---
builder.Services.AddCors(o => o.AddPolicy("dev", p => p.SetIsOriginAllowed(_ => true).AllowAnyHeader().AllowAnyMethod().AllowCredentials()));

// --- Rate limiting cho /api/auth (10 req/phút/IP) ---
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy("auth", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
    RateLimitPolicies.AddUserPolicies(o);
    o.OnRejected = async (c, ct) =>
    {
        c.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        await c.HttpContext.Response.WriteAsJsonAsync(new
        {
            type = "https://tools.ietf.org/html/rfc6585#section-4",
            title = "Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút",
            status = 429,
        }, (System.Text.Json.JsonSerializerOptions?)null, "application/problem+json", ct);
    };
});

// --- Swagger ---
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o =>
{
    o.SwaggerDoc("v1", new OpenApiInfo { Title = "GameHub API", Version = "v1" });
    o.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Dán token nhận được từ /api/auth/login (không cần chữ 'Bearer ').",
    });
    o.AddSecurityRequirement(doc => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", doc)] = [],
    });
});

var app = builder.Build();

app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.UseCors("dev");
}

// Swagger: luôn bật khi Development; ở Production bật bằng cấu hình Swagger:Enabled
// (trên VPS đặt biến môi trường Swagger__Enabled=true trong service systemd).
if (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled"))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Xác thực trước để rate limiter đọc được claim sub
app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();
app.MapControllers();
app.MapHub<GameHub.Api.Services.GameHub>("/hubs/game", o =>
    o.Transports = Microsoft.AspNetCore.Http.Connections.HttpTransportType.WebSockets
                   | Microsoft.AspNetCore.Http.Connections.HttpTransportType.LongPolling);

app.Run();
