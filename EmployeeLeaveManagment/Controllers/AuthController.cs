using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EmployeeLeaveManagment.Controllers;

[ApiController]
[Route("api/[controller]")]
[AllowAnonymous]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto? login)
    {
        if (login == null || string.IsNullOrWhiteSpace(login.UserName) || string.IsNullOrWhiteSpace(login.Password))
            return BadRequest(new { Message = "UserName and Password are required." });

        var result = await _authService.LoginAsync(login);
        if (result == null)
            return Unauthorized(new { Message = "Invalid username or password." });

        return Ok(result);
    }
}
