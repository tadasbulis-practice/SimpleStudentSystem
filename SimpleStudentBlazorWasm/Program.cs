using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using SimpleStudentBlazorWasm;
using SimpleStudentBlazorWasm.Services;

// This Program.cs runs IN THE BROWSER (WebAssembly), not on a server.
var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.RootComponents.Add<App>("#app");              // <div id="app"> in wwwroot/index.html
builder.RootComponents.Add<HeadOutlet>("head::after");

// ── API connection ────────────────────────────────────────────────────────────
// The list of backends comes from wwwroot/appsettings.json → "Backends".
// The URLs must be reachable FROM THE BROWSER (localhost:6001, not simplestudentapi:8080),
// because the browser itself sends the requests.
var backends = builder.Configuration.GetSection("Backends").GetChildren()
    .Select(b => new ApiBackend { Name = b["Name"] ?? "", Url = b["Url"] ?? "" })
    .ToList();
builder.Services.AddSingleton(backends);
builder.Services.AddScoped<ApiConnection>();

await builder.Build().RunAsync();
