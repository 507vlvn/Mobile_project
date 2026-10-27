using System.ComponentModel.DataAnnotations;

namespace GameHub.Api.model;

public record RegisterRequest(
    [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập")]
    [StringLength(50, MinimumLength = 3, ErrorMessage = "Tên đăng nhập phải từ 3 đến 50 ký tự")]
    [RegularExpression("^[a-zA-Z0-9_]+$", ErrorMessage = "Tên đăng nhập chỉ gồm chữ, số và dấu gạch dưới")]
    string Username,
    [Required(ErrorMessage = "Vui lòng nhập email")]
    [EmailAddress(ErrorMessage = "Email không hợp lệ")]
    [StringLength(100, ErrorMessage = "Email tối đa 100 ký tự")]
    string Email,
    [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
    [MinLength(6, ErrorMessage = "Mật khẩu phải có ít nhất 6 ký tự")]
    [MaxLength(72, ErrorMessage = "Mật khẩu tối đa 72 ký tự")]
    string Password,
    [StringLength(100, ErrorMessage = "Họ tên tối đa 100 ký tự")]
    string? FullName);

public record LoginRequest(
    [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập hoặc email")] string UsernameOrEmail,
    [Required(ErrorMessage = "Vui lòng nhập mật khẩu")] string Password);

public record UserDto(int UserId, string Username, string Email, string? FullName, string? AvatarUrl, DateTime CreatedAt);
public record UserSummaryDto(int UserId, string Username, string? FullName, string? AvatarUrl);
public record AuthResponse(string Token, UserDto User);

public record UpdateProfileRequest(
    [StringLength(100, ErrorMessage = "Họ tên tối đa 100 ký tự")] string? FullName,
    [StringLength(255, ErrorMessage = "Đường dẫn ảnh tối đa 255 ký tự")] string? AvatarUrl);

public record ChangePasswordRequest(
    [Required(ErrorMessage = "Vui lòng nhập mật khẩu hiện tại")] string CurrentPassword,
    [Required(ErrorMessage = "Vui lòng nhập mật khẩu mới")]
    [MinLength(6, ErrorMessage = "Mật khẩu phải có ít nhất 6 ký tự")]
    [MaxLength(72, ErrorMessage = "Mật khẩu tối đa 72 ký tự")]
    string NewPassword);

public record LevelDto(int LevelId, int Difficulty, string DifficultyName);
public record GameDto(int GameId, string GameCode, string GameName, string? Description, List<LevelDto> Levels);

public record SubmitHistoryRequest(
    [Required(ErrorMessage = "Thiếu mã game")] string GameCode,
    [Range(1, 3, ErrorMessage = "Độ khó phải từ 1 đến 3")] int Difficulty,
    [Range(1, 86400, ErrorMessage = "Thời gian chơi không hợp lệ")] int TimeSpentSeconds,
    [Range(0, 100000, ErrorMessage = "Số lỗi không hợp lệ")] int MistakesCount,
    [Range(0, 1000000, ErrorMessage = "Số nước đi không hợp lệ")] int MovesCount,
    [Range(0, 100000, ErrorMessage = "Số gợi ý không hợp lệ")] int HintsUsed,
    [Required(ErrorMessage = "Thiếu kết quả")] string Result,
    int? ChallengeId);

public record HistoryDto(
    int HistoryId, string GameCode, string GameName, int? Difficulty, string? DifficultyName,
    int TimeSpentSeconds, int MistakesCount, int MovesCount, int HintsUsed,
    string Result, int Score, int? ChallengeId, DateTime PlayedAt);

public record SubmitHistoryResponse(HistoryDto Record, bool IsPersonalBest, ChallengeDto? Challenge = null);

public record PagedResult<T>(List<T> Items, int Page, int PageSize, int Total);

public record LeaderboardEntryDto(
    int Rank, int UserId, string Username, string? FullName, string? AvatarUrl, int BestScore, int BestTimeSeconds,
    int? Rating = null, string? Tier = null, string? TierName = null, int? Games = null, int? Wins = null);
public record MyRankDto(
    int? Rank, int? BestScore, int? BestTimeSeconds,
    int? Rating = null, string? Tier = null, string? TierName = null, int? Games = null, int? Wins = null);

// ---- Thách đấu & tin nhắn ----

public record CreateChallengeRequest(
    [Range(1, int.MaxValue, ErrorMessage = "Đối thủ không hợp lệ")] int OpponentId,
    [Required(ErrorMessage = "Thiếu mã game")] string GameCode,
    [Range(1, 3, ErrorMessage = "Độ khó phải từ 1 đến 3")] int Difficulty);

public record ChallengeUserDto(int UserId, string Username, string? FullName);
public record ChallengeResultDto(int Score, int TimeSeconds, int Mistakes, string Result);

/// <summary>Seed của đề = ChallengeId; hai bên sinh cùng một đề từ seed này.</summary>
public record ChallengeDto(
    int Id, string GameCode, string GameName, int Difficulty, string Status,
    DateTime CreatedAt, DateTime? AcceptedAt, DateTime? CompletedAt,
    ChallengeUserDto Challenger, ChallengeUserDto Opponent,
    ChallengeResultDto? MyResult, ChallengeResultDto? TheirResult, int? WinnerId, int Seed);

public record SendMessageRequest(string? Content);
public record MessageDto(int MessageId, int SenderId, int ReceiverId, string Content, bool IsRead, DateTime SentAt);
public record ConversationDto(
    int UserId, string Username, string? FullName, string? AvatarUrl,
    string LastMessage, DateTime LastMessageAt, bool LastFromMe, int UnreadCount);
public record SocialSummaryDto(int UnreadMessages, int IncomingChallenges, int ActiveChallenges);

// ---- Mùa, bạn bè, hồ sơ, rating, trận ----

public record SeasonDto(DateTime StartUtc, DateTime EndUtc, DateTime Now);

/// <summary>status: online | in_match | offline.</summary>
public record FriendDto(int UserId, string Username, string? FullName, string? AvatarUrl, string Status, DateTime? LastSeenAt, DateTime? FriendsSince);

public record FriendRequestDto(int RequestId, int UserId, string Username, string? FullName, string? AvatarUrl, DateTime CreatedAt);
public record FriendRequestsDto(List<FriendRequestDto> Incoming, List<FriendRequestDto> Outgoing);
public record SendFriendRequest([Range(1, int.MaxValue, ErrorMessage = "Người chơi không hợp lệ")] int UserId);
/// <summary>status: PENDING (đã gửi) | ACCEPTED (đã thành bạn) | DECLINED.</summary>
public record FriendRequestResultDto(int RequestId, string Status, FriendDto? Friend);

public record GameStatsDto(
    string GameCode, string GameName, int Games, int Wins, int Losses, int Draws, int? BestRecordScore,
    int Rating, string Tier, string TierName, int PeakRating, int RatedGames);

public record ProfileDto(
    UserSummaryDto User, DateTime CreatedAt, bool IsFriend, string FriendshipStatus, int? PendingRequestId,
    string Status, DateTime? LastSeenAt, List<GameStatsDto> Stats);

public record RatingDto(
    string GameCode, string GameName, int Rating, string Tier, string TierName,
    int Games, int Wins, int Losses, int Draws, int PeakRating);

public record MatchHistoryDto(
    int MatchId, string GameCode, string GameName, int Difficulty, string Mode, string Kind,
    UserSummaryDto Opponent, string Result, string EndReason,
    int? RatingBefore, int? RatingAfter, int? RatingDelta, DateTime StartedAt, DateTime EndedAt, int DurationSeconds);

// Caro
public record SaveCaroGameRequest(
    [Required] string GameMode,
    [Range(1, 4)] int Difficulty,
    bool PlayerFirst,
    [Required] string HistoryData,
    [Range(0, 1000)] int Undos,
    [Range(0, 86400)] int ElapsedSeconds,
    [Range(0, 3)] int HintsRemaining);

public record CaroSavedGameDto(
    int Id,
    string GameMode,
    int Difficulty,
    bool PlayerFirst,
    string HistoryData,
    int Undos,
    int ElapsedSeconds,
    int HintsRemaining,
    DateTime UpdatedAt);
