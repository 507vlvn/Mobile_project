using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.model;

public class GameHubDbContext(DbContextOptions<GameHubDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Game> Games => Set<Game>();
    public DbSet<GameLevel> GameLevels => Set<GameLevel>();
    public DbSet<HistoryEntry> History => Set<HistoryEntry>();
    public DbSet<Challenge> Challenges => Set<Challenge>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<Friendship> Friendships => Set<Friendship>();
    public DbSet<PlayerRating> PlayerRatings => Set<PlayerRating>();
    public DbSet<GameMatch> Matches => Set<GameMatch>();
    public DbSet<SudokuProgress> SudokuProgresses => Set<SudokuProgress>();
    public DbSet<SudokuSavedGame> SudokuSavedGames => Set<SudokuSavedGame>();

    // Trả về false nếu lưu bị trùng khoá hoặc lỗi ràng buộc dữ liệu.
    public async Task<bool> TrySaveAsync(CancellationToken ct = default)
    {
        try
        {
            await SaveChangesAsync(ct);
            return true;
        }
        catch (DbUpdateException)
        {
            return false;
        }
    }

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<User>(e =>
        {
            e.ToTable("Users").HasKey(x => x.UserId);
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.Username).HasColumnName("username").HasMaxLength(50).IsUnicode(false);
            e.Property(x => x.PasswordHash).HasColumnName("password_hash").HasMaxLength(255).IsUnicode(false);
            e.Property(x => x.Email).HasColumnName("email").HasMaxLength(100).IsUnicode(false);
            e.Property(x => x.FullName).HasColumnName("full_name").HasMaxLength(100);
            e.Property(x => x.AvatarUrl).HasColumnName("avatar_url").HasMaxLength(255).IsUnicode(false);
            e.Property(x => x.IsActive).HasColumnName("is_active");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.Property(x => x.LastSeenAt).HasColumnName("last_seen_at");
            e.HasIndex(x => x.Username).IsUnique();
            e.HasIndex(x => x.Email).IsUnique();
        });

        b.Entity<Game>(e =>
        {
            e.ToTable("Games").HasKey(x => x.GameId);
            e.Property(x => x.GameId).HasColumnName("game_id");
            e.Property(x => x.GameCode).HasColumnName("game_code").HasMaxLength(50).IsUnicode(false);
            e.Property(x => x.GameName).HasColumnName("game_name").HasMaxLength(100);
            e.Property(x => x.Description).HasColumnName("description");
            e.HasMany(x => x.Levels).WithOne(l => l.Game).HasForeignKey(l => l.GameId).OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<GameLevel>(e =>
        {
            e.ToTable("GameLevels").HasKey(x => x.LevelId);
            e.Property(x => x.LevelId).HasColumnName("level_id");
            e.Property(x => x.GameId).HasColumnName("game_id");
            e.Property(x => x.Difficulty).HasColumnName("difficulty");
            e.Property(x => x.DifficultyName).HasColumnName("difficulty_name").HasMaxLength(20);
            e.Property(x => x.InitialState).HasColumnName("initial_state");
            e.Property(x => x.SolutionData).HasColumnName("solution_data");
        });

        b.Entity<HistoryEntry>(e =>
        {
            e.ToTable("History").HasKey(x => x.HistoryId);
            e.Property(x => x.HistoryId).HasColumnName("history_id");
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.GameId).HasColumnName("game_id");
            e.Property(x => x.LevelId).HasColumnName("level_id");
            e.Property(x => x.ChallengeId).HasColumnName("challenge_id");
            e.Property(x => x.MatchId).HasColumnName("match_id");
            e.Property(x => x.TimeSpentSeconds).HasColumnName("time_spent_seconds");
            e.Property(x => x.MistakesCount).HasColumnName("mistakes_count");
            e.Property(x => x.MovesCount).HasColumnName("moves_count");
            e.Property(x => x.HintsUsed).HasColumnName("hints_used");
            e.Property(x => x.Result).HasColumnName("result").HasMaxLength(20).IsUnicode(false);
            e.Property(x => x.Score).HasColumnName("score");
            e.Property(x => x.PlayedAt).HasColumnName("played_at");
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne(x => x.Game).WithMany().HasForeignKey(x => x.GameId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne(x => x.Level).WithMany().HasForeignKey(x => x.LevelId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne<Challenge>().WithMany().HasForeignKey(x => x.ChallengeId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne(x => x.Match).WithMany().HasForeignKey(x => x.MatchId).OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<Friendship>(e =>
        {
            e.ToTable("Friendships").HasKey(x => x.FriendshipId);
            e.Property(x => x.FriendshipId).HasColumnName("friendship_id");
            e.Property(x => x.RequesterId).HasColumnName("requester_id");
            e.Property(x => x.AddresseeId).HasColumnName("addressee_id");
            e.Property(x => x.UserLowId).HasColumnName("user_low");
            e.Property(x => x.UserHighId).HasColumnName("user_high");
            e.Property(x => x.Status).HasColumnName("status").HasMaxLength(20).IsUnicode(false);
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.Property(x => x.RespondedAt).HasColumnName("responded_at");
            e.HasOne(x => x.Requester).WithMany().HasForeignKey(x => x.RequesterId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne(x => x.Addressee).WithMany().HasForeignKey(x => x.AddresseeId).OnDelete(DeleteBehavior.NoAction);
            e.HasIndex(x => new { x.UserLowId, x.UserHighId }).IsUnique();
        });

        b.Entity<PlayerRating>(e =>
        {
            e.ToTable("PlayerRatings").HasKey(x => new { x.UserId, x.GameId });
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.GameId).HasColumnName("game_id");
            e.Property(x => x.Rating).HasColumnName("rating");
            e.Property(x => x.Games).HasColumnName("games");
            e.Property(x => x.Wins).HasColumnName("wins");
            e.Property(x => x.Losses).HasColumnName("losses");
            e.Property(x => x.Draws).HasColumnName("draws");
            e.Property(x => x.PeakRating).HasColumnName("peak_rating");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            e.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne<Game>().WithMany().HasForeignKey(x => x.GameId).OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<GameMatch>(e =>
        {
            e.ToTable("Matches").HasKey(x => x.MatchId);
            e.Property(x => x.MatchId).HasColumnName("match_id");
            e.Property(x => x.GameId).HasColumnName("game_id");
            e.Property(x => x.Difficulty).HasColumnName("difficulty");
            e.Property(x => x.Mode).HasColumnName("mode").HasMaxLength(10).IsUnicode(false);
            e.Property(x => x.Kind).HasColumnName("kind").HasMaxLength(10).IsUnicode(false);
            e.Property(x => x.Player1Id).HasColumnName("player1_id");
            e.Property(x => x.Player2Id).HasColumnName("player2_id");
            e.Property(x => x.WinnerId).HasColumnName("winner_id");
            e.Property(x => x.EndReason).HasColumnName("end_reason").HasMaxLength(20).IsUnicode(false);
            e.Property(x => x.Seed).HasColumnName("seed");
            e.Property(x => x.StartedAt).HasColumnName("started_at");
            e.Property(x => x.EndedAt).HasColumnName("ended_at");
            e.Property(x => x.P1RatingBefore).HasColumnName("p1_rating_before");
            e.Property(x => x.P1RatingAfter).HasColumnName("p1_rating_after");
            e.Property(x => x.P2RatingBefore).HasColumnName("p2_rating_before");
            e.Property(x => x.P2RatingAfter).HasColumnName("p2_rating_after");
            e.HasOne<Game>().WithMany().HasForeignKey(x => x.GameId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.Player1Id).OnDelete(DeleteBehavior.NoAction);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.Player2Id).OnDelete(DeleteBehavior.NoAction);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.WinnerId).OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<Challenge>(e =>
        {
            e.ToTable("Challenges").HasKey(x => x.ChallengeId);
            e.Property(x => x.ChallengeId).HasColumnName("challenge_id");
            e.Property(x => x.ChallengerId).HasColumnName("challenger_id");
            e.Property(x => x.OpponentId).HasColumnName("opponent_id");
            e.Property(x => x.GameId).HasColumnName("game_id");
            e.Property(x => x.LevelId).HasColumnName("level_id");
            e.Property(x => x.Status).HasColumnName("status").HasMaxLength(20).IsUnicode(false);
            e.Property(x => x.WinnerId).HasColumnName("winner_id");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.Property(x => x.AcceptedAt).HasColumnName("accepted_at");
            e.Property(x => x.CompletedAt).HasColumnName("completed_at");
            e.HasOne(x => x.Challenger).WithMany().HasForeignKey(x => x.ChallengerId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne(x => x.Opponent).WithMany().HasForeignKey(x => x.OpponentId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.WinnerId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne(x => x.Game).WithMany().HasForeignKey(x => x.GameId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne(x => x.Level).WithMany().HasForeignKey(x => x.LevelId).OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<Message>(e =>
        {
            e.ToTable("Messages").HasKey(x => x.MessageId);
            e.Property(x => x.MessageId).HasColumnName("message_id");
            e.Property(x => x.SenderId).HasColumnName("sender_id");
            e.Property(x => x.ReceiverId).HasColumnName("receiver_id");
            e.Property(x => x.Content).HasColumnName("content").HasMaxLength(2000);
            e.Property(x => x.IsRead).HasColumnName("is_read");
            e.Property(x => x.SentAt).HasColumnName("sent_at");
            e.HasOne<User>().WithMany().HasForeignKey(x => x.SenderId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne<User>().WithMany().HasForeignKey(x => x.ReceiverId).OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<SudokuProgress>(e =>
        {
            e.ToTable("SudokuProgresses").HasKey(x => x.Id);
            e.Property(x => x.Id).HasColumnName("id");
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.Level).HasColumnName("level");
            e.Property(x => x.IsUnlocked).HasColumnName("is_unlocked");
            e.Property(x => x.BestTimeSeconds).HasColumnName("best_time_seconds");
            e.Property(x => x.Mistakes).HasColumnName("mistakes");
            e.Property(x => x.CompletedAt).HasColumnName("completed_at");
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
            e.HasIndex(x => new { x.UserId, x.Level }).IsUnique();
        });

        b.Entity<SudokuSavedGame>(e =>
        {
            e.ToTable("SudokuSavedGames").HasKey(x => x.Id);
            e.Property(x => x.Id).HasColumnName("id");
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.GameMode).HasColumnName("game_mode").HasMaxLength(20).IsUnicode(false);
            e.Property(x => x.Level).HasColumnName("level");
            e.Property(x => x.Difficulty).HasColumnName("difficulty");
            e.Property(x => x.Seed).HasColumnName("seed");
            e.Property(x => x.BoardCurrent).HasColumnName("board_current").HasMaxLength(81).IsUnicode(false);
            e.Property(x => x.NotesData).HasColumnName("notes_data");
            e.Property(x => x.Mistakes).HasColumnName("mistakes");
            e.Property(x => x.ElapsedSeconds).HasColumnName("elapsed_seconds");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
            e.HasIndex(x => new { x.UserId, x.GameMode }).IsUnique();
        });
    }
}
