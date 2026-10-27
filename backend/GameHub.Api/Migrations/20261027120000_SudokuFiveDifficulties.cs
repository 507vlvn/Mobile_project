using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GameHub.Api.Migrations
{
    /// <summary>
    /// Sudoku có 5 mức (Dễ, Trung bình, Khó, Chuyên gia, Ác mộng):
    /// - nới CHECK độ khó của GameLevels và Matches lên 1..5, thêm 2 dòng GameLevels cho Sudoku;
    /// - CK_Matches_kind cho phép COOP (Sudoku đồng đội), trước đây trận đồng đội không ghi được.
    /// Các ràng buộc này có từ script schema.sql (không nằm trong model EF) nên viết bằng SQL,
    /// kiểm tra tồn tại trước khi xoá để chạy được cả trên DB tạo thuần bằng migration.
    /// </summary>
    public partial class SudokuFiveDifficulties : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                IF OBJECT_ID(N'CK_GameLevels_difficulty', N'C') IS NOT NULL
                    ALTER TABLE GameLevels DROP CONSTRAINT CK_GameLevels_difficulty;
                ALTER TABLE GameLevels ADD CONSTRAINT CK_GameLevels_difficulty CHECK (difficulty BETWEEN 1 AND 5);

                IF OBJECT_ID(N'CK_Matches_difficulty', N'C') IS NOT NULL
                    ALTER TABLE Matches DROP CONSTRAINT CK_Matches_difficulty;
                ALTER TABLE Matches ADD CONSTRAINT CK_Matches_difficulty CHECK (difficulty BETWEEN 1 AND 5);

                IF OBJECT_ID(N'CK_Matches_kind', N'C') IS NOT NULL
                    ALTER TABLE Matches DROP CONSTRAINT CK_Matches_kind;
                ALTER TABLE Matches ADD CONSTRAINT CK_Matches_kind CHECK (kind IN ('TURN', 'RACE', 'COOP'));

                INSERT INTO GameLevels (game_id, difficulty, difficulty_name)
                SELECT g.game_id, v.difficulty, v.name
                FROM Games g
                CROSS JOIN (VALUES (4, N'Chuyên gia'), (5, N'Ác mộng')) AS v(difficulty, name)
                WHERE g.game_code = 'SUDOKU'
                  AND NOT EXISTS (SELECT 1 FROM GameLevels l WHERE l.game_id = g.game_id AND l.difficulty = v.difficulty);
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Chỉ xoá mức 4-5 chưa có lịch sử / thách đấu trỏ tới; ràng buộc cũ dựng lại WITH NOCHECK
            // để không lỗi nếu đã có dữ liệu mức 4-5 hoặc trận COOP.
            migrationBuilder.Sql("""
                DELETE l FROM GameLevels l
                JOIN Games g ON g.game_id = l.game_id
                WHERE g.game_code = 'SUDOKU' AND l.difficulty IN (4, 5)
                  AND NOT EXISTS (SELECT 1 FROM History h WHERE h.level_id = l.level_id)
                  AND NOT EXISTS (SELECT 1 FROM Challenges c WHERE c.level_id = l.level_id);

                IF OBJECT_ID(N'CK_GameLevels_difficulty', N'C') IS NOT NULL
                    ALTER TABLE GameLevels DROP CONSTRAINT CK_GameLevels_difficulty;
                ALTER TABLE GameLevels WITH NOCHECK ADD CONSTRAINT CK_GameLevels_difficulty CHECK (difficulty BETWEEN 1 AND 3);

                IF OBJECT_ID(N'CK_Matches_difficulty', N'C') IS NOT NULL
                    ALTER TABLE Matches DROP CONSTRAINT CK_Matches_difficulty;
                ALTER TABLE Matches WITH NOCHECK ADD CONSTRAINT CK_Matches_difficulty CHECK (difficulty BETWEEN 1 AND 3);

                IF OBJECT_ID(N'CK_Matches_kind', N'C') IS NOT NULL
                    ALTER TABLE Matches DROP CONSTRAINT CK_Matches_kind;
                ALTER TABLE Matches WITH NOCHECK ADD CONSTRAINT CK_Matches_kind CHECK (kind IN ('TURN', 'RACE'));
                """);
        }
    }
}
