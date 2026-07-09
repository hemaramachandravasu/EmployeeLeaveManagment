using EmployeeLeaveManagment.DTOs;

namespace EmployeeLeaveManagment.Data;

public interface IDataWarehouseRepository
{
    Task<IEnumerable<ForecastDemandDto>> GetForecastLeaveDemandAsync(DateTime? asOfDate = null);
    Task<IEnumerable<BurnoutRiskDto>> GetEmployeeBurnoutRiskAsync(int lookbackDays = 180);
    Task<IEnumerable<PeakPeriodDto>> GetPeakLeavePeriodsAsync(int lookbackYears = 3, int topN = 10);
    Task<IEnumerable<MomTrendDto>> GetMonthOverMonthTrendAsync(int? year = null);
    Task<IEnumerable<DepartmentHeatmapDto>> GetDepartmentUtilizationHeatmapAsync(int? year = null);
    Task<IEnumerable<TopLeaveTypeDto>> GetTopLeaveTypesByVolumeAsync(int? year = null, int topN = 5);
    Task<IEnumerable<EtlRunLogDto>> GetEtlRunLogAsync(int topN = 20);
    Task<byte[]> ExportForecastDemandExcelAsync(DateTime? asOfDate = null);
    Task<byte[]> ExportBurnoutRiskExcelAsync(int lookbackDays = 180);
    Task<byte[]> ExportPeakPeriodsExcelAsync(int lookbackYears = 3, int topN = 10);
    Task<byte[]> ExportMomTrendExcelAsync(int? year = null);
    Task<string> ExportForecastDemandCsvAsync(DateTime? asOfDate = null);
    Task<string> ExportBurnoutRiskCsvAsync(int lookbackDays = 180);
    Task<string> ExportPeakPeriodsCsvAsync(int lookbackYears = 3, int topN = 10);
    Task<string> ExportMomTrendCsvAsync(int? year = null);
}
