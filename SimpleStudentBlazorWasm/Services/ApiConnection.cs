using SimpleStudentBlazorWasm.ApiClient;

namespace SimpleStudentBlazorWasm.Services;

/// <summary>One backend from wwwroot/appsettings.json → "Backends".</summary>
public class ApiBackend
{
    public string Name { get; set; } = "";
    /// <summary>Address YOUR BROWSER uses to call the API, e.g. http://localhost:6001.</summary>
    public string Url { get; set; } = "";
}

/// <summary>
/// Which API the app talks to, and the typed client for it.
/// All pages call the API through <see cref="Client"/> – the client generated from swagger.json.
/// In WebAssembly the HttpClient is the browser's fetch(): requests go straight from the browser
/// to the API, so the API must allow this origin with CORS.
/// </summary>
public class ApiConnection
{
    private IStudentApiClient? _client;

    public ApiConnection(List<ApiBackend> backends)
    {
        Backends = backends.Count > 0
            ? backends
            : new List<ApiBackend> { new() { Name = ".NET", Url = "http://localhost:6001" } };
        Current = Backends[0];
    }

    public IReadOnlyList<ApiBackend> Backends { get; }
    public ApiBackend Current { get; private set; }

    /// <summary>Raised after the backend was switched – pages reload their data.</summary>
    public event Action? Changed;

    public IStudentApiClient Client => _client ??= new StudentApiClient(new HttpClient { BaseAddress = ToBaseUri(Current.Url) });

    /// <summary>
    /// The generated client uses relative paths ("api/students"). With a sub-folder base address
    /// (XAMPP: http://localhost:8080/simpleStudentApi) the trailing "/" is required, otherwise
    /// .NET replaces the last segment: .../simpleStudentApi + api/students → .../api/students.
    /// </summary>
    public static Uri ToBaseUri(string url) => new(url.EndsWith('/') ? url : url + "/");

    /// <summary>Base address without the trailing "/" – for links and text on the pages.</summary>
    public string CurrentUrl => Current.Url.TrimEnd('/');

    /// <summary>Swagger UI of the selected API (works with and without a sub-folder).</summary>
    public string SwaggerUrl => CurrentUrl + "/swagger";

    public void Select(string name)
    {
        var backend = Backends.FirstOrDefault(b => b.Name == name);
        if (backend is null || backend == Current) return;
        Current = backend;
        _client = null;                 // the next call creates a client for the new address
        Changed?.Invoke();
    }
}
