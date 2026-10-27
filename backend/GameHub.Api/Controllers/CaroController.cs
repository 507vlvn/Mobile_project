using GameHub.Api.model;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GameHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/caro")]
public class CaroController(ICaroService caroService) : ApiControllerBase
{
    [HttpGet("saved-game")]
    public async Task<ActionResult<CaroSavedGameDto>> GetSavedGame(
        [FromQuery] string? mode = null,
        CancellationToken ct = default)
    {
        var savedGame = await caroService.GetSavedGameAsync(CurrentUserId, mode, ct);
        if (savedGame == null)
        {
            return NotFound(new { message = "Không tìm thấy ván chơi Caro dở dang." });
        }
        return Ok(savedGame);
    }

    [HttpPost("save-game")]
    public async Task<ActionResult<CaroSavedGameDto>> SaveGame(
        [FromBody] SaveCaroGameRequest request,
        CancellationToken ct)
    {
        var savedGame = await caroService.SaveGameAsync(CurrentUserId, request, ct);
        return Ok(savedGame);
    }

    [HttpDelete("saved-game")]
    public async Task<IActionResult> DeleteSavedGame(
        [FromQuery] string? mode = null,
        CancellationToken ct = default)
    {
        var deleted = await caroService.DeleteSavedGameAsync(CurrentUserId, mode, ct);
        if (!deleted)
        {
            return NotFound(new { success = false, message = "Không tìm thấy ván Caro dở để xóa." });
        }
        return Ok(new { success = true, message = "Đã xóa ván Caro dở dang thành công." });
    }
}
