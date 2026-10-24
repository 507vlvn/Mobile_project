using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GameHub.Api.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Games",
                columns: table => new
                {
                    game_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    game_code = table.Column<string>(type: "varchar(50)", unicode: false, maxLength: 50, nullable: false),
                    game_name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    description = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Games", x => x.game_id);
                });

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    user_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    username = table.Column<string>(type: "varchar(50)", unicode: false, maxLength: 50, nullable: false),
                    password_hash = table.Column<string>(type: "varchar(255)", unicode: false, maxLength: 255, nullable: false),
                    email = table.Column<string>(type: "varchar(100)", unicode: false, maxLength: 100, nullable: false),
                    full_name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    avatar_url = table.Column<string>(type: "varchar(255)", unicode: false, maxLength: 255, nullable: true),
                    is_active = table.Column<bool>(type: "bit", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2", nullable: false),
                    last_seen_at = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.user_id);
                });

            migrationBuilder.CreateTable(
                name: "GameLevels",
                columns: table => new
                {
                    level_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    game_id = table.Column<int>(type: "int", nullable: false),
                    difficulty = table.Column<int>(type: "int", nullable: false),
                    difficulty_name = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    initial_state = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    solution_data = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GameLevels", x => x.level_id);
                    table.ForeignKey(
                        name: "FK_GameLevels_Games_game_id",
                        column: x => x.game_id,
                        principalTable: "Games",
                        principalColumn: "game_id");
                });

            migrationBuilder.CreateTable(
                name: "Friendships",
                columns: table => new
                {
                    friendship_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    requester_id = table.Column<int>(type: "int", nullable: false),
                    addressee_id = table.Column<int>(type: "int", nullable: false),
                    user_low = table.Column<int>(type: "int", nullable: false),
                    user_high = table.Column<int>(type: "int", nullable: false),
                    status = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2", nullable: false),
                    responded_at = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Friendships", x => x.friendship_id);
                    table.ForeignKey(
                        name: "FK_Friendships_Users_addressee_id",
                        column: x => x.addressee_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                    table.ForeignKey(
                        name: "FK_Friendships_Users_requester_id",
                        column: x => x.requester_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                });

            migrationBuilder.CreateTable(
                name: "Matches",
                columns: table => new
                {
                    match_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    game_id = table.Column<int>(type: "int", nullable: false),
                    difficulty = table.Column<int>(type: "int", nullable: false),
                    mode = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false),
                    kind = table.Column<string>(type: "varchar(10)", unicode: false, maxLength: 10, nullable: false),
                    player1_id = table.Column<int>(type: "int", nullable: false),
                    player2_id = table.Column<int>(type: "int", nullable: false),
                    winner_id = table.Column<int>(type: "int", nullable: true),
                    end_reason = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    seed = table.Column<int>(type: "int", nullable: false),
                    started_at = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ended_at = table.Column<DateTime>(type: "datetime2", nullable: false),
                    p1_rating_before = table.Column<int>(type: "int", nullable: true),
                    p1_rating_after = table.Column<int>(type: "int", nullable: true),
                    p2_rating_before = table.Column<int>(type: "int", nullable: true),
                    p2_rating_after = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Matches", x => x.match_id);
                    table.ForeignKey(
                        name: "FK_Matches_Games_game_id",
                        column: x => x.game_id,
                        principalTable: "Games",
                        principalColumn: "game_id");
                    table.ForeignKey(
                        name: "FK_Matches_Users_player1_id",
                        column: x => x.player1_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                    table.ForeignKey(
                        name: "FK_Matches_Users_player2_id",
                        column: x => x.player2_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                    table.ForeignKey(
                        name: "FK_Matches_Users_winner_id",
                        column: x => x.winner_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                });

            migrationBuilder.CreateTable(
                name: "Messages",
                columns: table => new
                {
                    message_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    sender_id = table.Column<int>(type: "int", nullable: false),
                    receiver_id = table.Column<int>(type: "int", nullable: false),
                    content = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    is_read = table.Column<bool>(type: "bit", nullable: false),
                    sent_at = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Messages", x => x.message_id);
                    table.ForeignKey(
                        name: "FK_Messages_Users_receiver_id",
                        column: x => x.receiver_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                    table.ForeignKey(
                        name: "FK_Messages_Users_sender_id",
                        column: x => x.sender_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                });

            migrationBuilder.CreateTable(
                name: "PlayerRatings",
                columns: table => new
                {
                    user_id = table.Column<int>(type: "int", nullable: false),
                    game_id = table.Column<int>(type: "int", nullable: false),
                    rating = table.Column<int>(type: "int", nullable: false),
                    games = table.Column<int>(type: "int", nullable: false),
                    wins = table.Column<int>(type: "int", nullable: false),
                    losses = table.Column<int>(type: "int", nullable: false),
                    draws = table.Column<int>(type: "int", nullable: false),
                    peak_rating = table.Column<int>(type: "int", nullable: false),
                    updated_at = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlayerRatings", x => new { x.user_id, x.game_id });
                    table.ForeignKey(
                        name: "FK_PlayerRatings_Games_game_id",
                        column: x => x.game_id,
                        principalTable: "Games",
                        principalColumn: "game_id");
                    table.ForeignKey(
                        name: "FK_PlayerRatings_Users_user_id",
                        column: x => x.user_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                });

            migrationBuilder.CreateTable(
                name: "Challenges",
                columns: table => new
                {
                    challenge_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    challenger_id = table.Column<int>(type: "int", nullable: false),
                    opponent_id = table.Column<int>(type: "int", nullable: false),
                    game_id = table.Column<int>(type: "int", nullable: false),
                    level_id = table.Column<int>(type: "int", nullable: true),
                    status = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    winner_id = table.Column<int>(type: "int", nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime2", nullable: false),
                    accepted_at = table.Column<DateTime>(type: "datetime2", nullable: true),
                    completed_at = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Challenges", x => x.challenge_id);
                    table.ForeignKey(
                        name: "FK_Challenges_GameLevels_level_id",
                        column: x => x.level_id,
                        principalTable: "GameLevels",
                        principalColumn: "level_id");
                    table.ForeignKey(
                        name: "FK_Challenges_Games_game_id",
                        column: x => x.game_id,
                        principalTable: "Games",
                        principalColumn: "game_id");
                    table.ForeignKey(
                        name: "FK_Challenges_Users_challenger_id",
                        column: x => x.challenger_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                    table.ForeignKey(
                        name: "FK_Challenges_Users_opponent_id",
                        column: x => x.opponent_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                    table.ForeignKey(
                        name: "FK_Challenges_Users_winner_id",
                        column: x => x.winner_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                });

            migrationBuilder.CreateTable(
                name: "History",
                columns: table => new
                {
                    history_id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    game_id = table.Column<int>(type: "int", nullable: false),
                    level_id = table.Column<int>(type: "int", nullable: true),
                    challenge_id = table.Column<int>(type: "int", nullable: true),
                    match_id = table.Column<int>(type: "int", nullable: true),
                    time_spent_seconds = table.Column<int>(type: "int", nullable: false),
                    mistakes_count = table.Column<int>(type: "int", nullable: false),
                    moves_count = table.Column<int>(type: "int", nullable: false),
                    hints_used = table.Column<int>(type: "int", nullable: false),
                    result = table.Column<string>(type: "varchar(20)", unicode: false, maxLength: 20, nullable: false),
                    score = table.Column<int>(type: "int", nullable: false),
                    played_at = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_History", x => x.history_id);
                    table.ForeignKey(
                        name: "FK_History_Challenges_challenge_id",
                        column: x => x.challenge_id,
                        principalTable: "Challenges",
                        principalColumn: "challenge_id");
                    table.ForeignKey(
                        name: "FK_History_GameLevels_level_id",
                        column: x => x.level_id,
                        principalTable: "GameLevels",
                        principalColumn: "level_id");
                    table.ForeignKey(
                        name: "FK_History_Games_game_id",
                        column: x => x.game_id,
                        principalTable: "Games",
                        principalColumn: "game_id");
                    table.ForeignKey(
                        name: "FK_History_Matches_match_id",
                        column: x => x.match_id,
                        principalTable: "Matches",
                        principalColumn: "match_id");
                    table.ForeignKey(
                        name: "FK_History_Users_user_id",
                        column: x => x.user_id,
                        principalTable: "Users",
                        principalColumn: "user_id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_challenger_id",
                table: "Challenges",
                column: "challenger_id");

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_game_id",
                table: "Challenges",
                column: "game_id");

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_level_id",
                table: "Challenges",
                column: "level_id");

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_opponent_id",
                table: "Challenges",
                column: "opponent_id");

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_winner_id",
                table: "Challenges",
                column: "winner_id");

            migrationBuilder.CreateIndex(
                name: "IX_Friendships_addressee_id",
                table: "Friendships",
                column: "addressee_id");

            migrationBuilder.CreateIndex(
                name: "IX_Friendships_requester_id",
                table: "Friendships",
                column: "requester_id");

            migrationBuilder.CreateIndex(
                name: "IX_Friendships_user_low_user_high",
                table: "Friendships",
                columns: new[] { "user_low", "user_high" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_GameLevels_game_id",
                table: "GameLevels",
                column: "game_id");

            migrationBuilder.CreateIndex(
                name: "IX_History_challenge_id",
                table: "History",
                column: "challenge_id");

            migrationBuilder.CreateIndex(
                name: "IX_History_game_id",
                table: "History",
                column: "game_id");

            migrationBuilder.CreateIndex(
                name: "IX_History_level_id",
                table: "History",
                column: "level_id");

            migrationBuilder.CreateIndex(
                name: "IX_History_match_id",
                table: "History",
                column: "match_id");

            migrationBuilder.CreateIndex(
                name: "IX_History_user_id",
                table: "History",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_Matches_game_id",
                table: "Matches",
                column: "game_id");

            migrationBuilder.CreateIndex(
                name: "IX_Matches_player1_id",
                table: "Matches",
                column: "player1_id");

            migrationBuilder.CreateIndex(
                name: "IX_Matches_player2_id",
                table: "Matches",
                column: "player2_id");

            migrationBuilder.CreateIndex(
                name: "IX_Matches_winner_id",
                table: "Matches",
                column: "winner_id");

            migrationBuilder.CreateIndex(
                name: "IX_Messages_receiver_id",
                table: "Messages",
                column: "receiver_id");

            migrationBuilder.CreateIndex(
                name: "IX_Messages_sender_id",
                table: "Messages",
                column: "sender_id");

            migrationBuilder.CreateIndex(
                name: "IX_PlayerRatings_game_id",
                table: "PlayerRatings",
                column: "game_id");

            migrationBuilder.CreateIndex(
                name: "IX_Users_email",
                table: "Users",
                column: "email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_username",
                table: "Users",
                column: "username",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Friendships");

            migrationBuilder.DropTable(
                name: "History");

            migrationBuilder.DropTable(
                name: "Messages");

            migrationBuilder.DropTable(
                name: "PlayerRatings");

            migrationBuilder.DropTable(
                name: "Challenges");

            migrationBuilder.DropTable(
                name: "Matches");

            migrationBuilder.DropTable(
                name: "GameLevels");

            migrationBuilder.DropTable(
                name: "Users");

            migrationBuilder.DropTable(
                name: "Games");
        }
    }
}
