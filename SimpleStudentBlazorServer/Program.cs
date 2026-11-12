using SimpleStudentBlazorServer.Components;
using SimpleStudentBlazorServer.Services;

var builder = WebApplication.CreateBuilder(args);

// ── Blazor ────────────────────────────────────────────────────────────────────
// AddInteractiveServerComponents: the components run ON THE SERVER. The browser keeps a
// SignalR (WebSocket) connection open and receives only the changed parts of the page.
builder.Services.AddRazorComponents()
                .AddInteractiveServerComponents();

// ── API connection ────────────────────────────────────────────────────────────
// The list of backends (.NET, PHP, Python) comes from appsettings.json → "Backends".
// ApiConnection is SCOPED: in Blazor Server one scope = one browser tab (one "circuit"),
// so every user can switch the backend independently.
builder.Services.Configure<List<ApiBackend>>(builder.Configuration.GetSection("Backends"));
builder.Services.AddHttpClient();
builder.Services.AddScoped<ApiConnection>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
}

app.UseStaticFiles();
app.UseAntiforgery();

app.MapRazorComponents<App>()
   .AddInteractiveServerRenderMode();

app.Run();
