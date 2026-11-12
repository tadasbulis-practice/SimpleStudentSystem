using Microsoft.AspNetCore.Mvc.RazorPages;
using SimpleStudentFrontend.ApiClient;

namespace SimpleStudentFrontend.Pages;

public class IndexModel : PageModel
{
    private readonly IStudentApiClient _api;
    private readonly IConfiguration _configuration;

    public IndexModel(IStudentApiClient api, IConfiguration configuration)
    {
        _api = api;
        _configuration = configuration;
    }

    public InfoResponse? ApiInfo { get; private set; }
    public string? ErrorMessage { get; private set; }
    public string ApiBaseUrl => _configuration["ApiSettings:BaseUrl"] ?? "http://localhost:6001";

    public async Task OnGetAsync()
    {
        try
        {
            // Generated from operationId "GetInfo"  →  GET /api/info
            ApiInfo = await _api.GetInfoAsync();
        }
        catch (Exception ex)
        {
            ErrorMessage = ApiErrors.ToMessage(ex);
        }
    }
}
