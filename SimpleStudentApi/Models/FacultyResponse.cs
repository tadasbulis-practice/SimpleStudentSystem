namespace SimpleStudentApi.Models;

/// <summary>
/// Response DTOs for the GET /api/faculty endpoint.
/// These are NOT EF entities — they are pure output shapes.
/// </summary>

public class FacultyResponse
{
    public string             Name   { get; set; } = "Faculty of Technology";
    public List<GroupResponse> Groups { get; set; } = new();
}

public class GroupResponse
{
    public string         Code           { get; set; } = string.Empty;
    public string         StudyProgram   { get; set; } = string.Empty;
    public int            EnrollmentYear { get; set; }
    public List<Student>  Students       { get; set; } = new();
}
