namespace SimpleStudentApi.Models;

/// <summary>Basic information about the running API.</summary>
public class InfoResponse
{
    /// <example>SimpleStudentApi</example>
    public string Service { get; set; } = string.Empty;

    /// <example>1.2</example>
    public string Version { get; set; } = string.Empty;

    /// <summary>"ok" when the service is healthy.</summary>
    /// <example>ok</example>
    public string Status { get; set; } = string.Empty;

    /// <example>Student CRUD API with SQL Server</example>
    public string Message { get; set; } = string.Empty;

    /// <summary>ASP.NET Core environment (Development / Production).</summary>
    /// <example>Production</example>
    public string Environment { get; set; } = string.Empty;

    /// <summary>Main endpoints of this API.</summary>
    public List<string> Endpoints { get; set; } = new();

    /// <summary>Server time in UTC.</summary>
    public DateTime TimestampUtc { get; set; }
}
