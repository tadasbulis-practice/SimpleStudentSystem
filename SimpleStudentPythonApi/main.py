"""
SimpleStudentPythonApi – the same Students REST API as SimpleStudentApi (.NET) and
SimpleStudentPhpApi, written in Python with FastAPI.

  Contract:  generated from the Pydantic models in models.py (code-first, like the .NET API)
             served at /swagger/v1/swagger.json – the same URL as the .NET and PHP APIs
  Swagger:   /swagger
  Database:  MySQL (XAMPP), SQL Server (Docker) or SQLite – chosen with DB_DRIVER (config.py)

Run it:
  local:   python main.py                      → http://localhost:6003/swagger
  Docker:  docker-compose up --build           → http://localhost:6003/swagger
"""

import os
import platform
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

import config
import database as db
import problems
from models import FacultyResponse, GroupResponse, HttpValidationProblemDetails, InfoResponse, Student

HERE = Path(__file__).parent


@asynccontextmanager
async def lifespan(app: FastAPI):
    db.prepare_database()          # create the Students table if needed (like EnsureCreated in .NET)
    yield


app = FastAPI(
    title="SimpleStudentPythonApi",
    version="v1",
    description="Student CRUD API (Python + FastAPI + SQLAlchemy) used in the Heterogeneous Systems "
                "Docker lab. Same contract as SimpleStudentApi (.NET) and SimpleStudentPhpApi.",
    openapi_url="/swagger/v1/swagger.json",   # same URL as the .NET API
    docs_url=None,                            # our own Swagger UI page below (works without internet)
    redoc_url=None,
    separate_input_output_schemas=False,      # one "Student" schema, as in .NET
    lifespan=lifespan,
)

# Browser apps on other origins (JavaScript frontends, Swagger UI elsewhere) may call the API
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
                   expose_headers=["Location"])

problems.register(app)

# Response descriptions for Swagger
NOT_FOUND = {404: {"description": "Not Found"}}
BAD_REQUEST = {400: {"model": HttpValidationProblemDetails, "description": "Bad Request"}}


# ── Swagger UI ────────────────────────────────────────────────────────────────
app.mount("/swagger-ui", StaticFiles(directory=HERE / "swagger-ui"), name="swagger-ui")

SWAGGER_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>SimpleStudentPythonApi – Swagger</title>
    <!-- Swagger UI files are bundled in swagger-ui/ (works without internet). The contract comes from this API. -->
    <link rel="stylesheet" href="/swagger-ui/swagger-ui.css">
    <link rel="icon" href="/swagger-ui/favicon-32x32.png">
    <style>
        body { margin: 0; }
        .py-banner { background: #3776ab; color: #ffd43b; font: bold 14px Arial, sans-serif; padding: 8px 20px; }
    </style>
</head>
<body>
<div class="py-banner">Python %PYVER% + FastAPI implementation of the SimpleStudentApi contract</div>
<div id="swagger-ui"></div>
<script src="/swagger-ui/swagger-ui-bundle.js"></script>
<script>
    SwaggerUIBundle({ url: "/swagger/v1/swagger.json", dom_id: "#swagger-ui" });
</script>
</body>
</html>"""


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse("/swagger", status_code=302)


@app.get("/swagger", include_in_schema=False)
@app.get("/swagger/index.html", include_in_schema=False)
def swagger_ui():
    return HTMLResponse(SWAGGER_PAGE.replace("%PYVER%", platform.python_version()))


# ── Info ──────────────────────────────────────────────────────────────────────
@app.get("/api/info", response_model=InfoResponse, operation_id="GetInfo", tags=["Info"],
         summary="Service information",
         description="Returns basic health information about the API. "
                     "Useful to check that the container is running.")
def get_info():
    return InfoResponse(
        service="SimpleStudentPythonApi",
        version="1.2",
        status="ok",
        message=f"Student CRUD API in Python {platform.python_version()} + FastAPI "
                f"(database: {config.DB_DRIVER})",
        environment=config.APP_ENVIRONMENT,
        endpoints=["/api/students", "/api/students/{id}", "/api/faculty", "/swagger"],
        timestamp_utc=datetime.now(timezone.utc),
    )


# ── Students CRUD ─────────────────────────────────────────────────────────────
@app.get("/api/students", response_model=list[Student], operation_id="GetStudents",
         tags=["Students"], summary="List all students")
def get_students():
    return db.all_students()


@app.get("/api/students/{id}", response_model=Student, operation_id="GetStudent",
         tags=["Students"], summary="Get one student by ID", responses=NOT_FOUND)
def get_student(id: int):
    student = db.find_student(id)
    return student if student else problems.problem(404, "Not Found")


@app.post("/api/students", response_model=Student, status_code=201, operation_id="CreateStudent",
          tags=["Students"], summary="Create a new student", responses=BAD_REQUEST,
          description="The `id` in the request body is ignored – the database generates it. "
                      "Returns the created student with its new ID.")
def create_student(student: Student, response: Response):
    created = db.create_student(student.model_dump(by_alias=True))
    response.headers["Location"] = f"/api/students/{created['id']}"
    return created


@app.put("/api/students/{id}", response_model=Student, operation_id="UpdateStudent",
         tags=["Students"], summary="Update an existing student", responses={**BAD_REQUEST, **NOT_FOUND})
def update_student(id: int, student: Student):
    updated = db.update_student(id, student.model_dump(by_alias=True))
    return updated if updated else problems.problem(404, "Not Found")


@app.delete("/api/students/{id}", status_code=204, response_class=Response, operation_id="DeleteStudent",
            tags=["Students"], summary="Delete a student", responses=NOT_FOUND)
def delete_student(id: int):
    if not db.delete_student(id):
        return problems.problem(404, "Not Found")
    return Response(status_code=204)


# ── Faculty hierarchy ─────────────────────────────────────────────────────────
def build_group_code(study_program: str, year: int) -> str:
    """"Computer Science", 2024 → "CS-24" (same rule as the .NET and PHP APIs)."""
    prefix = "".join(word[0].upper() for word in study_program.split())
    return f"{prefix}-{year % 100:02d}"


@app.get("/api/faculty", response_model=FacultyResponse, operation_id="GetFaculty", tags=["Faculty"],
         summary="Faculty → groups → students",
         description='Groups students by study program and enrollment year, '
                     'e.g. "CS-24" for Computer Science 2024.')
def get_faculty():
    grouped: dict[tuple[str, int], list[dict]] = {}
    for s in db.all_students():
        grouped.setdefault((s["studyProgram"], s["enrollmentYear"]), []).append(s)

    groups = [
        GroupResponse(
            code=build_group_code(program, year),
            study_program=program,
            enrollment_year=year,
            students=sorted(members, key=lambda s: (s["lastName"], s["firstName"])),
        )
        for (program, year), members in sorted(grouped.items())
    ]
    return FacultyResponse(name="Faculty of Technology", groups=groups)


# ── swagger.json: make it match the .NET contract ─────────────────────────────
def custom_openapi() -> dict:
    """
    FastAPI's generated document, with three small changes so it matches the .NET swagger.json:
      1. no "422 Validation Error" responses – this API answers 400 instead (problems.py)
      2. 400 responses use the content type application/problem+json
      3. no automatic "title" on every property (C# does not add them)
    """
    if app.openapi_schema:
        return app.openapi_schema

    doc = get_openapi(title=app.title, version=app.version, description=app.description, routes=app.routes)

    for path in doc["paths"].values():
        for operation in path.values():
            responses = operation.get("responses", {})
            responses.pop("422", None)
            if "400" in responses and "content" in responses["400"]:
                responses["400"]["content"] = {problems.PROBLEM_JSON: responses["400"]["content"]["application/json"]}
            for parameter in operation.get("parameters", []):
                parameter.get("schema", {}).pop("title", None)

    schemas = doc.get("components", {}).get("schemas", {})
    schemas.pop("HTTPValidationError", None)
    schemas.pop("ValidationError", None)
    for schema in schemas.values():
        schema.pop("title", None)
        for prop in schema.get("properties", {}).values():
            prop.pop("title", None)

    app.openapi_schema = doc
    return doc


app.openapi = custom_openapi


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=os.getenv("HOST", "127.0.0.1"), port=int(os.getenv("PORT", "6003")))
