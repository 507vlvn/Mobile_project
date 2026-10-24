using Microsoft.AspNetCore.Mvc;
using GameHub.Api.Infrastructure;

namespace GameHub.Api.Controllers;

[ApiController]
public abstract class ApiControllerBase : ControllerBase
{
    protected int CurrentUserId => User.GetUserId();
}
