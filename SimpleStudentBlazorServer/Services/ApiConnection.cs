using Microsoft.Extensions.Options;
using SimpleStudentBlazorServer.ApiClient;

namespace SimpleStudentBlazorServer.Services;

/// <summary>One backend from appsettings.json → "Backends".</summary>
public class ApiBackend
{
    public string Name { get; set; } = "";
    /// <summary>Address the SERVER uses to call the API (in Docker: http://simplestudentapi:8080).</summary>
    public string BaseUrl { get; set; } = "";
    /// <summary>Address YOUR BROWSER uses (links to Swagger), e.g. http://localhost:6001.</summary>
    public string PublicUrl { get; set; } = "";
}

/// <summary>
/// Which API this browser tab talks to, and the typed client for it.
/// All pages call the API through <see cref="Client"/> – the client generated from swagger.json.
/// Because .NET, PHP and Python APIs share one contract, the same client works with all of them.
/// </summary>
public class ApiConnection
{
    private readonly IHttpClientFactory _httpClientFactory;
    private IStudentApiClient? _client;

    public ApiConnection(IOptions<List<ApiBackend>> backends, IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
        Backends = backends.Value.Count > 0
            ? backends.Value
            : new List<ApiBackend> { new() { Name = ".NET", BaseUrl = "http://localhost:6001", PublicUrl = "http://localhost:6001" } };
        Current = Backends[0];
    }

    public IReadOnlyList<ApiBackend> Backends { get; }
    public ApiBackend Current { get; private set; }

    /// <summary>Raised after the backend was switched – pages reload their data.</summary>
    public event Action? Changed;

    public IStudentApiClient Client => _client ??= CreateClient(Current);

    public void Select(string name)
    {
        var backend = Backends.FirstOrDefault(b => b.Name == name);
        if (backend is null || backend == Current) return;
        Current = backend;
        _client = null;                 // the next call creates a client for the new address
        Changed?.Invoke();
    }

    private IStudentApiClient CreateClient(ApiBackend backend)
    {
        // IHttpClientFactory manages the connections; we only set the base address.
        var http = _httpClientFactory.CreateClient();
        http.BaseAddress = ToBaseUri(backend.BaseUrl);
        return new StudentApiClient(http);
    }

    /// <summary>
    /// The generated client uses relative paths ("api/students"). With a sub-folder base address
    /// (XAMPP: http://localhost:8080/simpleStudentApi) the trailing "/" is required, otherwise
    /// .NET replaces the last segment: .../simpleStudentApi + api/students → .../api/students.
    /// </summary>
    public static Uri ToBaseUri(string url) => new(url.EndsWith('/') ? url : url + "/");

    /// <summary>Swagger UI of the selected API (works with and without a sub-folder).</summary>
    public string SwaggerUrl => Current.PublicUrl.TrimEnd('/') + "/swagger";
}
