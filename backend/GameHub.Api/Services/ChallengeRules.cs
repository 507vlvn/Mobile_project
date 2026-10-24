namespace GameHub.Api.Services;

public enum ChallengeBox { Incoming, Outgoing, Active, Done, All }

/// <summary>Quy tắc thuần (không đụng DB) cho thách đấu và tin nhắn — dễ kiểm thử.</summary>
public static class ChallengeRules
{
    public const string Pending = "PENDING";
    public const string Accepted = "ACCEPTED";
    public const string Declined = "DECLINED";
    public const string Completed = "COMPLETED";
    public const string Expired = "EXPIRED";

    public static readonly string[] DoneStatuses = [Completed, Declined, Expired];
    public static readonly string[] OpenStatuses = [Pending, Accepted];

    public static readonly TimeSpan PendingLifetime = TimeSpan.FromDays(7);
    public const int MaxMessageLength = 1000;

    public static DateTime ExpiryCutoff(DateTime utcNow) => utcNow - PendingLifetime;

    public static bool IsExpired(string status, DateTime createdAtUtc, DateTime utcNow) =>
        status == Pending && createdAtUtc <= ExpiryCutoff(utcNow);

    public static bool TryParseBox(string? value, out ChallengeBox box)
    {
        switch (value?.Trim().ToLowerInvariant())
        {
            case "incoming": box = ChallengeBox.Incoming; return true;
            case "outgoing": box = ChallengeBox.Outgoing; return true;
            case "active": box = ChallengeBox.Active; return true;
            case "done": box = ChallengeBox.Done; return true;
            case "all": box = ChallengeBox.All; return true;
            default: box = default; return false;
        }
    }

    /// <summary>
    /// Người thắng: điểm cao hơn; bằng điểm thì thời gian ngắn hơn; vẫn bằng thì hoà (null).
    /// Nếu cả hai đều 0 điểm (không ai hoàn thành) cũng coi là hoà.
    /// </summary>
    public static int? DecideWinner(int userA, int scoreA, int timeA, int userB, int scoreB, int timeB)
    {
        if (scoreA != scoreB) return scoreA > scoreB ? userA : userB;
        if (scoreA == 0) return null;
        if (timeA != timeB) return timeA < timeB ? userA : userB;
        return null;
    }

    /// <summary>Chuẩn hoá nội dung tin nhắn: cắt khoảng trắng, 1..1000 ký tự.</summary>
    public static bool TryNormalizeMessage(string? content, out string normalized, out string? error)
    {
        normalized = content?.Trim() ?? "";
        if (normalized.Length == 0) { error = "Tin nhắn không được để trống"; return false; }
        if (normalized.Length > MaxMessageLength)
        {
            error = $"Tin nhắn tối đa {MaxMessageLength} ký tự";
            return false;
        }
        error = null;
        return true;
    }

    /// <summary>Số trang/limit hợp lệ cho danh sách tin nhắn.</summary>
    public static int ClampLimit(int? limit) => Math.Clamp(limit ?? 30, 1, 100);
}
