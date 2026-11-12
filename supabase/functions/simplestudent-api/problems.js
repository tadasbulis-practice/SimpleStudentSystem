/*
 * Error responses in the same format as ASP.NET Core, the PHP and the Python API:
 * RFC 9457 problem details, Content-Type: application/problem+json.
 * Every client that understands the .NET API's errors understands these.
 */

export const PROBLEM_JSON = 'application/problem+json';

/** Sends {type, title, status, ...extra} with the given HTTP status. */
export function sendProblem(res, status, title, extra = {}, type = '') {
    res.status(status)
       .type(PROBLEM_JSON)
       .send(JSON.stringify({ type: type || `https://httpstatuses.io/${status}`, title, status, ...extra }));
}

/** 400 with field errors – the same as Results.ValidationProblem(errors) in .NET. */
export function sendValidationProblem(res, errors) {
    sendProblem(res, 400, 'One or more validation errors occurred.', { errors },
                'https://tools.ietf.org/html/rfc9110#section-15.5.1');
}
