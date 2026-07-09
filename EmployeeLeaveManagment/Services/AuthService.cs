using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;
using EmployeeLeaveManagment.Security;

namespace EmployeeLeaveManagment.Services;

public interface IAuthService
{
    Task<LoginResponseDto?> LoginAsync(LoginDto login);
}

public class AuthService : IAuthService
{
    private readonly IUserRepository _userRepository;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IConfiguration _configuration;

    public AuthService(IUserRepository userRepository, IJwtTokenService jwtTokenService, IConfiguration configuration)
    {
        _userRepository = userRepository;
        _jwtTokenService = jwtTokenService;
        _configuration = configuration;
    }

    public async Task<LoginResponseDto?> LoginAsync(LoginDto login)
    {
        var user = await _userRepository.GetByUserNameAsync(login.UserName);
        if (user == null || !PasswordHasher.Verify(login.Password, user.PasswordHash))
            return null;

        int expiresMinutes = _configuration.GetValue("Jwt:ExpiresMinutes", 60);
        return new LoginResponseDto
        {
            Token = _jwtTokenService.CreateToken(user.UserId, user.UserName, user.RoleName, user.EmployeeId, user.DepartmentId),
            UserName = user.UserName,
            Role = user.RoleName,
            ExpiresAt = DateTime.UtcNow.AddMinutes(expiresMinutes)
        };
    }
}
