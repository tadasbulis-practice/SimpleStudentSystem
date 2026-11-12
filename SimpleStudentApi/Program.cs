using System.Reflection;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi;
using SimpleStudentApi.Data;
using SimpleStudentApi.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// ── Swagger / OpenAPI ─────────────────────────────────────────────────────────
// 1. AddEndpointsApiExplorer  – lets ASP.NET Core discover Minimal API endpoints
// 2. AddSwaggerGen            – builds the OpenAPI document (swagger.json) from them
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title       = "SimpleStudentApi",
        Version     = "v1",
        Description = "Student CRUD API (.NET 8 Minimal API + EF Core + SQL Server) used in the Heterogeneous Systems Docker lab."
    });

    // Read /// <summary> and <example> comments from the Models folder
    // (the .csproj sets GenerateDocumentationFile = true)
    var xmlFile = Path.Combine(AppContext.BaseDirectory, $"{Assembly.GetExecutingAssembly().GetName().Name}.xml");
    options.IncludeXmlComments(xmlFile);

    // Treat non-nullable C# strings (string vs string?) as non-nullable in the schema
    options.SupportNonNullableReferenceTypes();
});

// ── CORS ──────────────────────────────────────────────────────────────────────
// Lets JavaScript / Blazor WebAssembly apps on OTHER addresses (e.g. http://localhost:6041)
// call this API directly from the browser. Server-side frontends (Razor Pages, Blazor Server, PHP)
// do not need it – the browser only enforces CORS for its own requests.
// For a real public API list the allowed origins instead of AllowAnyOrigin().
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy => policy
        .AllowAnyOrigin()
        .AllowAnyHeader()
        .AllowAnyMethod()
        .WithExposedHeaders("Location")));

var app = builder.Build();

// Auto-create DB on startup (with retry for slow MSSQL boot)
using (var scope = app.Services.CreateScope())
{
    var maxRetries = 10;
    for (int i = 0; i < maxRetries; i++)
    {
        try
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.EnsureCreated();
            Console.WriteLine("Database ready.");
            break;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"DB not ready yet (attempt {i + 1}/{maxRetries}): {ex.Message}");
            if (i == maxRetries - 1) throw;
            Thread.Sleep(3000);
        }
    }
}

// 3. UseSwagger    – serves the JSON document at /swagger/v1/swagger.json
// 4. UseSwaggerUI  – serves the interactive web page at /swagger
// NOTE: enabled in every environment so it also works inside Docker (Production).
//       In a real production system you would usually wrap this in
//       if (app.Environment.IsDevelopment()) { ... } or protect it.
app.UseCors();

app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "SimpleStudentApi v1");
    options.DocumentTitle = "SimpleStudentApi – Swagger";
});

// ── Info ──────────────────────────────────────────────────────────────────────
app.MapGet("/", () => Results.Redirect("/swagger"))
   .ExcludeFromDescription();                       // hide from Swagger

app.MapGet("/api/info", () => Results.Ok(new InfoResponse
    {
        Service      = "SimpleStudentApi",
        Version      = "1.2",
        Status       = "ok",
        Message      = "Student CRUD API with SQL Server",
        Environment  = app.Environment.EnvironmentName,
        Endpoints    = new() { "/api/students", "/api/students/{id}", "/api/faculty", "/swagger" },
        TimestampUtc = DateTime.UtcNow
    }))
   .WithName("GetInfo")                             // operationId → method name in generated clients
   .WithTags("Info")                                // group in Swagger UI
   .WithSummary("Service information")
   .WithDescription("Returns basic health information about the API. Useful to check that the container is running.")
   .Produces<InfoResponse>(StatusCodes.Status200OK);

// ── Students CRUD ─────────────────────────────────────────────────────────────
var students = app.MapGroup("/api/students").WithTags("Students");

students.MapGet("/", async (AppDbContext db) =>
        Results.Ok(await db.Students.ToListAsync()))
   .WithName("GetStudents")
   .WithSummary("List all students")
   .Produces<List<Student>>(StatusCodes.Status200OK);

students.MapGet("/{id:int}", async (int id, AppDbContext db) =>
    {
        var student = await db.Students.FindAsync(id);
        return student is null ? Results.NotFound() : Results.Ok(student);
    })
   .WithName("GetStudent")
   .WithSummary("Get one student by ID")
   .Produces<Student>(StatusCodes.Status200OK)
   .Produces(StatusCodes.Status404NotFound);

students.MapPost("/", async (Student student, AppDbContext db) =>
    {
        var errors = StudentValidator.Validate(student);
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        student.Id = 0;                             // the database generates the ID
        db.Students.Add(student);
        await db.SaveChangesAsync();
        return Results.Created($"/api/students/{student.Id}", student);
    })
   .WithName("CreateStudent")
   .WithSummary("Create a new student")
   .WithDescription("The `id` in the request body is ignored – SQL Server generates it. Returns the created student with its new ID.")
   .Produces<Student>(StatusCodes.Status201Created)
   .ProducesValidationProblem();                    // 400 with field errors

students.MapPut("/{id:int}", async (int id, Student updated, AppDbContext db) =>
    {
        var errors = StudentValidator.Validate(updated);
        if (errors.Count > 0) return Results.ValidationProblem(errors);

        var student = await db.Students.FindAsync(id);
        if (student is null) return Results.NotFound();

        student.FirstName      = updated.FirstName;
        student.LastName       = updated.LastName;
        student.Email          = updated.Email;
        student.StudyProgram   = updated.StudyProgram;
        student.EnrollmentYear = updated.EnrollmentYear;

        await db.SaveChangesAsync();
        return Results.Ok(student);
    })
   .WithName("UpdateStudent")
   .WithSummary("Update an existing student")
   .Produces<Student>(StatusCodes.Status200OK)
   .ProducesValidationProblem()
   .Produces(StatusCodes.Status404NotFound);

students.MapDelete("/{id:int}", async (int id, AppDbContext db) =>
    {
        var student = await db.Students.FindAsync(id);
        if (student is null) return Results.NotFound();

        db.Students.Remove(student);
        await db.SaveChangesAsync();
        return Results.NoContent();
    })
   .WithName("DeleteStudent")
   .WithSummary("Delete a student")
   .Produces(StatusCodes.Status204NoContent)
   .Produces(StatusCodes.Status404NotFound);

// ── Faculty hierarchy  ────────────────────────────────────────────────────────
// Returns Faculty → Groups → Students
// Groups are derived by grouping students on StudyProgram + EnrollmentYear.
// This is the endpoint that Lab-7's ApiStudentRepository calls.

app.MapGet("/api/faculty", async (AppDbContext db) =>
    {
        var all = await db.Students.ToListAsync();

        var groups = all
            .GroupBy(s => new { s.StudyProgram, s.EnrollmentYear })
            .Select(g => new GroupResponse
            {
                Code           = BuildGroupCode(g.Key.StudyProgram, g.Key.EnrollmentYear),
                StudyProgram   = g.Key.StudyProgram,
                EnrollmentYear = g.Key.EnrollmentYear,
                Students       = g.OrderBy(s => s.LastName).ThenBy(s => s.FirstName).ToList()
            })
            .OrderBy(g => g.StudyProgram)
            .ThenBy(g => g.EnrollmentYear)
            .ToList();

        return Results.Ok(new FacultyResponse
        {
            Name   = "Faculty of Technology",
            Groups = groups
        });
    })
   .WithName("GetFaculty")
   .WithTags("Faculty")
   .WithSummary("Faculty → groups → students")
   .WithDescription("Groups students by study program and enrollment year, e.g. \"CS-24\" for Computer Science 2024.")
   .Produces<FacultyResponse>(StatusCodes.Status200OK);

app.Run();

// ── Helpers ───────────────────────────────────────────────────────────────────
static string BuildGroupCode(string studyProgram, int year)
{
    var words  = studyProgram.Split(' ', StringSplitOptions.RemoveEmptyEntries);
    var prefix = string.Concat(words.Select(w => char.ToUpper(w[0])));
    return $"{prefix}-{year % 100:D2}";
}

static class StudentValidator
{
    /// <summary>Simple input checks. Errors are returned as HTTP 400 (ValidationProblem).</summary>
    public static Dictionary<string, string[]> Validate(Student s)
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(s.FirstName))    errors["firstName"]    = new[] { "First name is required." };
        if (string.IsNullOrWhiteSpace(s.LastName))     errors["lastName"]     = new[] { "Last name is required." };
        if (string.IsNullOrWhiteSpace(s.Email) || !s.Email.Contains('@'))
                                                       errors["email"]        = new[] { "A valid email is required." };
        if (string.IsNullOrWhiteSpace(s.StudyProgram)) errors["studyProgram"] = new[] { "Study program is required." };
        if (s.EnrollmentYear is < 2000 or > 2100)      errors["enrollmentYear"] = new[] { "Enrollment year must be between 2000 and 2100." };
        return errors;
    }
}
