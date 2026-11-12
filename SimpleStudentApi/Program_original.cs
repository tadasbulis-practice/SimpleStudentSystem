// using Microsoft.EntityFrameworkCore;
// using SimpleStudentApi.Data;
// using SimpleStudentApi.Models;

// var builder = WebApplication.CreateBuilder(args);

// // Register EF Core with SQL Server
// builder.Services.AddDbContext<AppDbContext>(options =>
//     options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// var app = builder.Build();

// // Auto-create the database and Students table on startup (with retry for slow MSSQL boot)
// using (var scope = app.Services.CreateScope())
// {
//     var maxRetries = 10;
//     for (int i = 0; i < maxRetries; i++)
//     {
//         try
//         {
//             var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
//             db.Database.EnsureCreated();
//             Console.WriteLine("Database ready.");
//             break;
//         }
//         catch (Exception ex)
//         {
//             Console.WriteLine($"DB not ready yet (attempt {i + 1}/{maxRetries}): {ex.Message}");
//             if (i == maxRetries - 1) throw;
//             Thread.Sleep(3000);
//         }
//     }
// }

// // ── Info ─────────────────────────────────────────────────────────────────────

// app.MapGet("/", () => Results.Redirect("/api/info"));

// app.MapGet("/api/info", () => Results.Json(new
// {
//     service = "SimpleStudentApi",
//     version = "1.0",
//     status = "ok",
//     message = "Hello from .NET 8 Minimal API",
//     timestampUtc = DateTime.UtcNow,
//     environment = app.Environment.EnvironmentName
// }));

// // ── Students CRUD ─────────────────────────────────────────────────────────────

// // GET all students
// app.MapGet("/api/students", async (AppDbContext db) =>
//     Results.Ok(await db.Students.ToListAsync()));

// // GET single student by id
// app.MapGet("/api/students/{id:int}", async (int id, AppDbContext db) =>
// {
//     var student = await db.Students.FindAsync(id);
//     return student is null ? Results.NotFound() : Results.Ok(student);
// });

// // POST create student
// app.MapPost("/api/students", async (Student student, AppDbContext db) =>
// {
//     db.Students.Add(student);
//     await db.SaveChangesAsync();
//     return Results.Created($"/api/students/{student.Id}", student);
// });

// // PUT update student
// app.MapPut("/api/students/{id:int}", async (int id, Student updated, AppDbContext db) =>
// {
//     var student = await db.Students.FindAsync(id);
//     if (student is null) return Results.NotFound();

//     student.FirstName     = updated.FirstName;
//     student.LastName      = updated.LastName;
//     student.Email         = updated.Email;
//     student.StudyProgram  = updated.StudyProgram;
//     student.EnrollmentYear = updated.EnrollmentYear;

//     await db.SaveChangesAsync();
//     return Results.Ok(student);
// });

// // DELETE student
// app.MapDelete("/api/students/{id:int}", async (int id, AppDbContext db) =>
// {
//     var student = await db.Students.FindAsync(id);
//     if (student is null) return Results.NotFound();

//     db.Students.Remove(student);
//     await db.SaveChangesAsync();
//     return Results.NoContent();
// });

// app.Run();
