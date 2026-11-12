namespace SimpleStudentBlazorWasm.ApiClient;

/// <summary>Turns exceptions from the generated client into readable messages for the pages.</summary>
public static class ApiErrors
{
    public static string ToMessage(Exception ex) => ex switch
    {
        // 400 – the API returned validation errors (HttpValidationProblemDetails, documented in Swagger)
        ApiException<HttpValidationProblemDetails> v when v.Result?.Errors is { Count: > 0 } errors =>
            "Validation failed: " + string.Join(" ", errors.SelectMany(e => e.Value)),

        // 404 and other HTTP status codes
        ApiException api when api.StatusCode == 404 => "Student not found (404).",
        ApiException api => $"API returned {api.StatusCode}.",

        // API not reachable, DNS, timeout ...
        HttpRequestException http => $"Cannot reach the API: {http.Message}",
        _ => ex.Message
    };

    /// <summary>
    /// Field errors from a 400 response, e.g. { "firstName": ["First name is required."] }.
    /// The form shows them next to the matching input fields.
    /// </summary>
    public static IDictionary<string, ICollection<string>> FieldErrors(Exception ex) =>
        ex is ApiException<HttpValidationProblemDetails> v && v.Result?.Errors is { } errors
            ? errors
            : new Dictionary<string, ICollection<string>>();
}
