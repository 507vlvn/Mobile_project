namespace GameHub.Api.Services;

/// <summary>
/// Đọc file .env dạng KEY=VALUE (bỏ qua dòng trống và dòng bắt đầu bằng #) thành biến môi trường.
/// Dùng "__" để biểu diễn cấp cấu hình, ví dụ ConnectionStrings__DefaultConnection.
/// Không ghi đè biến môi trường đã có sẵn.
/// </summary>
public static class DotEnv
{
    public static void Load(string path)
    {
        if (!File.Exists(path)) return;
        foreach (var raw in File.ReadAllLines(path))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#')) continue;
            var eq = line.IndexOf('=');
            if (eq <= 0) continue;
            var key = line[..eq].Trim();
            var value = line[(eq + 1)..].Trim();
            if (value.Length >= 2 && (value[0] == '"' || value[0] == '\'') && value[^1] == value[0])
                value = value[1..^1];
            if (Environment.GetEnvironmentVariable(key) is null)
                Environment.SetEnvironmentVariable(key, value);
        }
    }
}
