using SimpleStudentFrontend.ApiClient;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

// Typed API client generated from the API's Swagger document (see ApiClient/ folder).
// IStudentApiClient is injected into the pages; HttpClient.BaseAddress decides which API it talks to.
//   - in Docker:  http://simplestudentapi:8080  (set in docker-compose.yml)
//   - locally:    http://localhost:6001         (appsettings.json)
builder.Services.AddHttpClient<IStudentApiClient, StudentApiClient>(client =>
{
    var apiBaseUrl = builder.Configuration["ApiSettings:BaseUrl"] ?? "http://localhost:6001";
    client.BaseAddress = new Uri(apiBaseUrl);
});

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();
app.MapRazorPages();
app.Run();
