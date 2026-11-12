using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SimpleStudentFrontend.ApiClient;
using SimpleStudentFrontend.Models;

namespace SimpleStudentFrontend.Pages;

public class StudentCreateModel : PageModel
{
    private readonly IStudentApiClient _api;

    public StudentCreateModel(IStudentApiClient api) => _api = api;

    [BindProperty]
    public StudentDto Input { get; set; } = new() { EnrollmentYear = DateTime.Now.Year };

    public string? ErrorMessage { get; private set; }

    public async Task<IActionResult> OnPostAsync()
    {
        try
        {
            // POST /api/students  →  201 Created (or 400 with validation errors)
            await _api.CreateStudentAsync(Input.ToApi());
            return RedirectToPage("/Students");
        }
        catch (Exception ex)
        {
            ErrorMessage = ApiErrors.ToMessage(ex);
            return Page();
        }
    }
}
