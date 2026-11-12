using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SimpleStudentFrontend.ApiClient;

namespace SimpleStudentFrontend.Pages;

public class StudentsModel : PageModel
{
    private readonly IStudentApiClient _api;

    public StudentsModel(IStudentApiClient api) => _api = api;

    public List<Student> Students { get; private set; } = new();
    public string? ErrorMessage { get; private set; }

    public async Task OnGetAsync()
    {
        try
        {
            // GET /api/students
            Students = (await _api.GetStudentsAsync()).ToList();
        }
        catch (Exception ex)
        {
            ErrorMessage = ApiErrors.ToMessage(ex);
        }
    }

    public async Task<IActionResult> OnPostDeleteAsync(int id)
    {
        try
        {
            // DELETE /api/students/{id}
            await _api.DeleteStudentAsync(id);
            return RedirectToPage();
        }
        catch (Exception ex)
        {
            // Show the error on the list instead of silently redirecting
            await OnGetAsync();
            ErrorMessage = "Delete failed: " + ApiErrors.ToMessage(ex);
            return Page();
        }
    }
}
