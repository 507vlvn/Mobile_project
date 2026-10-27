using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GameHub.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddCaroSavedGames : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CaroSavedGames",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    game_mode = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    difficulty = table.Column<int>(type: "int", nullable: false),
                    player_first = table.Column<bool>(type: "bit", nullable: false),
                    history_data = table.Column<string>(type: "varchar(max)", unicode: false, nullable: false),
                    undos = table.Column<int>(type: "int", nullable: false),
                    elapsed_seconds = table.Column<int>(type: "int", nullable: false),
                    hints_remaining = table.Column<int>(type: "int", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CaroSavedGames", x => x.id);
                    table.ForeignKey(
                        name: "FK_CaroSavedGames_Users_user_id",
                        column: x => x.user_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_CaroSavedGames_user_id_game_mode",
                table: "CaroSavedGames",
                columns: new[] { "user_id", "game_mode" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CaroSavedGames");
        }
    }
}
