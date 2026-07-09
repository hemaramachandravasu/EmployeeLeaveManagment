using EmployeeLeaveManagment.Services;
using Microsoft.Extensions.Caching.Memory;

namespace EmployeeLeaveManagment.Services
{
    public class MemoryCacheService : ICacheService
    {
        private readonly IMemoryCache _cache;

        public MemoryCacheService(IMemoryCache cache)
        {
            _cache = cache;
        }

        public T? Get<T>(string key)
        {
            return _cache.TryGetValue(key, out T value) ? value : default;
        }

        public void Set<T>(string key, T value, int expirationMinutes)
        {
            var options = new MemoryCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(expirationMinutes),
                SlidingExpiration = TimeSpan.FromMinutes(expirationMinutes / 2)
            };

            _cache.Set(key, value, options);
        }

        public void Remove(string key)
        {
            _cache.Remove(key);
        }

        public bool TryGetValue<T>(string key, out T value)
        {
            if (_cache.TryGetValue(key, out T cacheValue))
            {
                value = cacheValue;
                return true;
            }

            value = default!;
            return false;
        }
    }
}