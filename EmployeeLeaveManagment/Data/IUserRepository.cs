using EmployeeLeaveManagment.Models;

namespace EmployeeLeaveManagment.Data;

public interface IUserRepository
{
    Task<User?> GetByUserNameAsync(string userName);
}
