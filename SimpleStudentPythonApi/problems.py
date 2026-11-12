"""
Error responses in the same format as ASP.NET Core and the PHP API:
RFC 9457 problem details, Content-Type: application/problem+json.

FastAPI's own defaults are different (status 422, {"detail": [...]}), so we replace them here.
That keeps the contract identical: every client that works with the .NET API works with this one.
"""

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError
from starlette.exceptions import HTTPException as StarletteHTTPException

import config

PROBLEM_JSON = "application/problem+json"

# The same messages as StudentValidator in the .NET API
FIELD_MESSAGES = {
    "firstName":      "First name is required.",
    "lastName":       "Last name is required.",
    "email":          "A valid email is required.",
    "studyProgram":   "Study program is required.",
    "enrollmentYear": "Enrollment year must be between 2000 and 2100.",
}


def problem(status: int, title: str, extra: dict | None = None, type_: str = "") -> JSONResponse:
    body = {"type": type_ or f"https://httpstatuses.io/{status}", "title": title, "status": status}
    body.update(extra or {})
    return JSONResponse(status_code=status, content=body, media_type=PROBLEM_JSON)


def validation_problem(errors: dict[str, list[str]]) -> JSONResponse:
    """400 with field errors – the same as Results.ValidationProblem(errors) in .NET."""
    return problem(400, "One or more validation errors occurred.", {"errors": errors},
                   "https://tools.ietf.org/html/rfc9110#section-15.5.1")


def _label(field: str) -> str:
    """"studyProgram" → "Study program"."""
    words = "".join(f" {c}" if c.isupper() else c for c in field)
    return words.strip().capitalize()


async def on_request_validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
    errors: dict[str, list[str]] = {}
    for err in exc.errors():
        loc = err.get("loc", ())
        # /api/students/abc – the .NET route {id:int} does not match, so .NET answers 404
        if loc and loc[0] == "path":
            return problem(404, "Not Found")
        # The body is missing, is not valid JSON or is not an object
        if len(loc) < 2 or err.get("type") in ("json_invalid", "model_attributes_type", "dict_type"):
            return problem(400, "The request body must be a JSON object.")
        field = str(loc[1])
        if err.get("type") == "string_too_long":
            message = f"{_label(field)} must be at most {err['ctx']['max_length']} characters."
        else:
            message = FIELD_MESSAGES.get(field, err.get("msg", "Invalid value."))
        errors.setdefault(field, [])
        if message not in errors[field]:
            errors[field].append(message)
    return validation_problem(errors)


async def on_http_error(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    if exc.status_code == 404:
        return problem(404, f"No endpoint {request.method} {request.url.path}",
                       {"detail": "See /swagger for all endpoints."})
    if exc.status_code == 405:
        return problem(405, f"Method {request.method} is not allowed for {request.url.path}",
                       {"detail": "See /swagger for all endpoints."})
    return problem(exc.status_code, str(exc.detail))


async def on_database_error(request: Request, exc: SQLAlchemyError) -> JSONResponse:
    text = str(exc)
    hint = ("Has the table been created? The API creates it on start-up when the database StudentDb exists."
            if "Students" in text
            else "Check the DB_* settings (config.py / docker-compose.yml) and that the database server is running.")
    return problem(500, "Database error", {"detail": text, "hint": hint} if config.APP_DEBUG else {})


async def on_unexpected_error(request: Request, exc: Exception) -> JSONResponse:
    return problem(500, "Server error", {"detail": str(exc)} if config.APP_DEBUG else {})


def register(app: FastAPI) -> None:
    app.add_exception_handler(RequestValidationError, on_request_validation_error)
    app.add_exception_handler(StarletteHTTPException, on_http_error)
    app.add_exception_handler(SQLAlchemyError, on_database_error)
    app.add_exception_handler(Exception, on_unexpected_error)
