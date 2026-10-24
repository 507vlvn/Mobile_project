using GameHub.Api.model;
using GameHub.Api.Repositories;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Controllers;

[ApiController]
[Route("api/games")]
public class GamesController(IGameRepository games) : ApiControllerBase
{
    [HttpGet]
    public async Task<List<GameDto>> GetAll(CancellationToken ct)
    {
        var list = await games.Games().AsNoTracking().Include(g => g.Levels).OrderBy(g => g.GameId).ToListAsync(ct);
        return list.Select(g => new GameDto(g.GameId, g.GameCode, g.GameName, g.Description,
            g.Levels.OrderBy(l => l.Difficulty).ThenBy(l => l.LevelId)
                .Select(l => new LevelDto(l.LevelId, l.Difficulty, l.DifficultyName)).ToList())).ToList();
    }
}
