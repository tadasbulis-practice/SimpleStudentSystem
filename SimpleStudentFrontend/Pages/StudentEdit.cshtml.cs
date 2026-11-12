using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SimpleStudentFrontend.ApiClient;
using SimpleStudentFrontend.Models;

namespace SimpleStudentFrontend.Pages;

public class StudentEditModel : PageModel
{
    private readonly IStudentApiClient _api;

    public StudentEditModel(IStudentApiClient api) => _api = api;

    [BindProperty]
    public StudentDto Input { get; set; } = new();

    public string? ErrorMessage { get; private set; }

    public async Task<IActionResult> OnGetAsync(int id)
    {
        try
        {
            // GET /api/students/{id}
            Input = StudentDto.FromApi(await _api.GetStudentAsync(id));
        }
        catch (ApiException ex) when (ex.StatusCode == 404)
        {
            return NotFound();
        }
        catch (Exception ex)
        {
            ErrorMessage = ApiErrors.ToMessage(ex);
        }
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        try
        {
            // PUT /api/students/{id}  →  200 OK (or 400 / 404)
            await _api.UpdateStudentAsync(Input.Id, Input.ToApi());
            return RedirectToPage("/Students");
        }
        catch (Exception ex)
        {
            ErrorMessage = ApiErrors.ToMessage(ex);
            return Page();
        }
    }
}
