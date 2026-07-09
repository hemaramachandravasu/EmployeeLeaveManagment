using EmployeeLeaveManagment.Data;
using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Services;

public class DataWarehouseService : IDataWarehouseService
{
    private readonly IDataWarehouseRepository _repository;

    public DataWarehouseService(IDataWarehouseRepository repository)
    {
        _repository = repository;
    }

    public Task<IEnumerable<ForecastDemandDto>> GetForecastLeaveDemandAsync(DateTime? asOfDate = null)
        => _repository.GetForecastLeaveDemandAsync(asOfDate);

    public Task<IEnumerable<BurnoutRiskDto>> GetEmployeeBurnoutRiskAsync(int lookbackDays = 180)
        => _repository.GetEmployeeBurnoutRiskAsync(lookbackDays);

    public Task<IEnumerable<PeakPeriodDto>> GetPeakLeavePeriodsAsync(int lookbackYears = 3, int topN = 10)
        => _repository.GetPeakLeavePeriodsAsync(lookbackYears, topN);

    public Task<IEnumerable<MomTrendDto>> GetMonthOverMonthTrendAsync(int? year = null)
        => _repository.GetMonthOverMonthTrendAsync(year);

    public Task<IEnumerable<DepartmentHeatmapDto>> GetDepartmentUtilizationHeatmapAsync(int? year = null)
        => _repository.GetDepartmentUtilizationHeatmapAsync(year);

    public Task<IEnumerable<TopLeaveTypeDto>> GetTopLeaveTypesByVolumeAsync(int? year = null, int topN = 5)
        => _repository.GetTopLeaveTypesByVolumeAsync(year, topN);

    public Task<IEnumerable<EtlRunLogDto>> GetEtlRunLogAsync(int topN = 20)
        => _repository.GetEtlRunLogAsync(topN);

    public Task<byte[]> ExportForecastDemandExcelAsync(DateTime? asOfDate = null)
        => _repository.ExportForecastDemandExcelAsync(asOfDate);

    public Task<byte[]> ExportBurnoutRiskExcelAsync(int lookbackDays = 180)
        => _repository.ExportBurnoutRiskExcelAsync(lookbackDays);

    public Task<byte[]> ExportPeakPeriodsExcelAsync(int lookbackYears = 3, int topN = 10)
        => _repository.ExportPeakPeriodsExcelAsync(lookbackYears, topN);

    public Task<byte[]> ExportMomTrendExcelAsync(int? year = null)
        => _repository.ExportMomTrendExcelAsync(year);

    public Task<string> ExportForecastDemandCsvAsync(DateTime? asOfDate = null)
        => _repository.ExportForecastDemandCsvAsync(asOfDate);

    public Task<string> ExportBurnoutRiskCsvAsync(int lookbackDays = 180)
        => _repository.ExportBurnoutRiskCsvAsync(lookbackDays);

    public Task<string> ExportPeakPeriodsCsvAsync(int lookbackYears = 3, int topN = 10)
        => _repository.ExportPeakPeriodsCsvAsync(lookbackYears, topN);

    public Task<string> ExportMomTrendCsvAsync(int? year = null)
        => _repository.ExportMomTrendCsvAsync(year);
}
