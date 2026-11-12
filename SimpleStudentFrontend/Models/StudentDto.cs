using SimpleStudentFrontend.ApiClient;

namespace SimpleStudentFrontend.Models;

/// <summary>
/// Form model used by the Create/Edit pages.
/// The API contract type is <see cref="Student"/> (generated from Swagger);
/// we map between them so the HTML form is independent of the API.
/// </summary>
public class StudentDto
{
    public int Id { get; set; }
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public string? Email { get; set; }
    public string? StudyProgram { get; set; }
    public int EnrollmentYear { get; set; }

    public static StudentDto FromApi(Student s) => new()
    {
        Id = s.Id,
        FirstName = s.FirstName,
        LastName = s.LastName,
        Email = s.Email,
        StudyProgram = s.StudyProgram,
        EnrollmentYear = s.EnrollmentYear
    };

    public Student ToApi() => new()
    {
        Id = Id,
        FirstName = FirstName ?? string.Empty,
        LastName = LastName ?? string.Empty,
        Email = Email ?? string.Empty,
        StudyProgram = StudyProgram ?? string.Empty,
        EnrollmentYear = EnrollmentYear
    };
}
