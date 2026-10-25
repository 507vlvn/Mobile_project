using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GameHub.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSudokuDifficultyStats : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "SudokuDifficultyStats",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    difficulty = table.Column<int>(type: "int", nullable: false),
                    games_started = table.Column<int>(type: "int", nullable: false),
                    games_won = table.Column<int>(type: "int", nullable: false),
                    win_without_mistakes = table.Column<int>(type: "int", nullable: false),
                    best_time_seconds = table.Column<int>(type: "int", nullable: true),
                    total_win_time_seconds = table.Column<int>(type: "int", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SudokuDifficultyStats", x => x.id);
                    table.ForeignKey(
                        name: "FK_SudokuDifficultyStats_Users_user_id",
                        column: x => x.user_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_SudokuDifficultyStats_user_id_difficulty",
                table: "SudokuDifficultyStats",
                columns: new[] { "user_id", "difficulty" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SudokuDifficultyStats");
        }
    }
}
