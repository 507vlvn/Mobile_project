using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GameHub.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSudokuTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "SudokuProgresses",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    level = table.Column<int>(type: "int", nullable: false),
                    is_unlocked = table.Column<bool>(type: "bit", nullable: false),
                    best_time_seconds = table.Column<int>(type: "int", nullable: true),
                    mistakes = table.Column<int>(type: "int", nullable: true),
                    completed_at = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SudokuProgresses", x => x.id);
                    table.ForeignKey(
                        name: "FK_SudokuProgresses_Users_user_id",
                        column: x => x.user_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                });

            migrationBuilder.CreateTable(
                name: "SudokuSavedGames",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    game_mode = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    level = table.Column<int>(type: "int", nullable: true),
                    difficulty = table.Column<int>(type: "int", nullable: false),
                    seed = table.Column<long>(type: "bigint", nullable: false),
                    board_current = table.Column<string>(type: "varchar(81)", unicode: false, maxLength: 81, nullable: false),
                    notes_data = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    mistakes = table.Column<int>(type: "int", nullable: false),
                    elapsed_seconds = table.Column<int>(type: "int", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SudokuSavedGames", x => x.id);
                    table.ForeignKey(
                        name: "FK_SudokuSavedGames_Users_user_id",
                        column: x => x.user_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_SudokuProgresses_user_id_level",
                table: "SudokuProgresses",
                columns: new[] { "user_id", "level" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SudokuSavedGames_user_id_game_mode",
                table: "SudokuSavedGames",
                columns: new[] { "user_id", "game_mode" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SudokuProgresses");

            migrationBuilder.DropTable(
                name: "SudokuSavedGames");
        }
    }
}
