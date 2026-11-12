using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SimpleStudentFrontend.ApiClient;

namespace SimpleStudentFrontend.Pages;

/// <summary>Details of one student: /Student?id=5</summary>
public class StudentModel : PageModel
{
    private readonly IStudentApiClient _api;

    public StudentModel(IStudentApiClient api) => _api = api;

    public Student? Student { get; private set; }
    public string? ErrorMessage { get; private set; }

    public async Task<IActionResult> OnGetAsync(int? id)
    {
        if (id is null) return RedirectToPage("/Students");
        try
        {
            // GET /api/students/{id}
            Student = await _api.GetStudentAsync(id.Value);
        }
        catch (Exception ex)
        {
            ErrorMessage = ApiErrors.ToMessage(ex);
        }
        return Page();
    }
}
