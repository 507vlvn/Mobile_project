using GameHub.Api.model;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GameHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/sudoku")]
public class SudokuController(ISudokuService sudokuService) : ApiControllerBase
{
    // ==========================================
    // 1. TIẾN TRÌNH HỌC TẬP (LEARNING MODE)
    // ==========================================

    [HttpGet("progress")]
    public async Task<ActionResult<SudokuProgressSummaryDto>> GetProgress(CancellationToken ct)
    {
        var summary = await sudokuService.GetProgressSummaryAsync(CurrentUserId, ct);
        return Ok(summary);
    }

    [HttpPost("progress")]
    public async Task<ActionResult<UpdateSudokuProgressResponse>> UpdateProgress(
        [FromBody] UpdateSudokuProgressRequest request,
        CancellationToken ct)
    {
        var response = await sudokuService.RecordWinAsync(CurrentUserId, request, ct);
        return Ok(response);
    }

    // ==========================================
    // 2. VÁN CHƠI DỞ DANG (SAVE / RESUME)
    // ==========================================

    [HttpGet("saved-game")]
    public async Task<ActionResult<SudokuSavedGameDto>> GetSavedGame(
        [FromQuery] string mode = "CLASSIC",
        CancellationToken ct = default)
    {
        var savedGame = await sudokuService.GetSavedGameAsync(CurrentUserId, mode, ct);
        if (savedGame == null)
        {
            return NotFound(new { message = "Không tìm thấy ván chơi dở dang." });
        }
        return Ok(savedGame);
    }

    [HttpPost("save-game")]
    public async Task<ActionResult<SudokuSavedGameDto>> SaveGame(
        [FromBody] SaveSudokuGameRequest request,
        CancellationToken ct)
    {
        var savedGame = await sudokuService.SaveGameAsync(CurrentUserId, request, ct);
        return Ok(savedGame);
    }

    [HttpDelete("saved-game")]
    public async Task<IActionResult> DeleteSavedGame(
        [FromQuery] string mode = "CLASSIC",
        CancellationToken ct = default)
    {
        var deleted = await sudokuService.DeleteSavedGameAsync(CurrentUserId, mode, ct);
        if (!deleted)
        {
            return NotFound(new { success = false, message = "Không tìm thấy ván chơi dở để xóa." });
        }
        return Ok(new { success = true, message = "Đã xóa ván chơi dở dang thành công." });
    }

    // ==========================================
    // 3. THỐNG KÊ THEO ĐỘ KHÓ (DIFFICULTY STATS)
    // ==========================================

    [HttpGet("stats")]
    public async Task<ActionResult<List<DifficultyStatsDto>>> GetStats(CancellationToken ct)
    {
        var stats = await sudokuService.GetDifficultyStatsAsync(CurrentUserId, ct);
        return Ok(stats);
    }

    [HttpPost("stats/record")]
    public async Task<ActionResult<DifficultyStatsDto>> RecordStat(
        [FromBody] RecordSudokuStatRequest request,
        CancellationToken ct)
    {
        var stat = await sudokuService.RecordDifficultyStatAsync(CurrentUserId, request, ct);
        return Ok(stat);
    }
}
