"""
Database access with SQLAlchemy Core – one code base for MySQL, SQL Server and SQLite.

The table and column names are exactly the ones the .NET API (EF Core) creates,
so the .NET, PHP and Python APIs can share one table.
"""

import time

from sqlalchemy import (Column, Integer, MetaData, Table, Unicode, create_engine,
                        delete, func, insert, select, update)
from sqlalchemy.engine import URL, Engine

import config

metadata = MetaData()

students_table = Table(
    "Students", metadata,
    Column("Id",             Integer,      primary_key=True, autoincrement=True),
    Column("FirstName",      Unicode(100), nullable=False),   # NVARCHAR on SQL Server, VARCHAR on MySQL
    Column("LastName",       Unicode(100), nullable=False),
    Column("Email",          Unicode(200), nullable=False),
    Column("StudyProgram",   Unicode(100), nullable=False),
    Column("EnrollmentYear", Integer,      nullable=False),
)

# Column name in the database  <->  field name in the JSON (camelCase, as in .NET and PHP)
COLUMNS = {
    "Id": "id", "FirstName": "firstName", "LastName": "lastName", "Email": "email",
    "StudyProgram": "studyProgram", "EnrollmentYear": "enrollmentYear",
}

DEMO_STUDENTS = [
    {"FirstName": "Jonas", "LastName": "Jonaitis",     "Email": "jonas@kk.lt", "StudyProgram": "Computer Science", "EnrollmentYear": 2024},
    {"FirstName": "Ieva",  "LastName": "Kazlauskaitė", "Email": "ieva@kk.lt",  "StudyProgram": "Computer Science", "EnrollmentYear": 2024},
    {"FirstName": "Amir",  "LastName": "Haddad",       "Email": "amir@kk.lt",  "StudyProgram": "Software Systems", "EnrollmentYear": 2025},
]


def build_url() -> URL:
    """Connection URL for the driver chosen in config.py."""
    if config.DB_DRIVER == "sqlite":
        return URL.create("sqlite", database=config.SQLITE_FILE)
    if config.DB_DRIVER == "sqlsrv":
        try:
            import pymssql  # noqa: F401  (installed in the Docker image; locally: pip install -r requirements-mssql.txt)
        except ImportError:
            raise SystemExit("DB_DRIVER=sqlsrv needs the package pymssql: pip install -r requirements-mssql.txt")
        return URL.create("mssql+pymssql", username=config.DB_USER, password=config.DB_PASSWORD,
                          host=config.DB_HOST, port=int(config.DB_PORT), database=config.DB_NAME)
    if config.DB_DRIVER == "mysql":
        return URL.create("mysql+pymysql", username=config.DB_USER, password=config.DB_PASSWORD,
                          host=config.DB_HOST, port=int(config.DB_PORT), database=config.DB_NAME,
                          query={"charset": "utf8mb4"})
    raise ValueError(f"Unknown DB_DRIVER '{config.DB_DRIVER}'. Use mysql, sqlsrv or sqlite.")


engine: Engine = create_engine(build_url(), pool_pre_ping=True)


def prepare_database(retries: int = 10, delay_seconds: float = 3) -> None:
    """
    Creates the Students table if it does not exist (like EnsureCreated() in the .NET API).
    Retries for a while, because SQL Server in Docker needs some time to start.
    The database itself (StudentDb) must exist – see database/<driver>/create.sql in the PHP API.
    With SQLite the file is created and filled with demo data automatically.
    """
    for attempt in range(1, retries + 1):
        try:
            metadata.create_all(engine)
            if config.DB_DRIVER == "sqlite":
                with engine.begin() as conn:
                    if conn.execute(select(func.count()).select_from(students_table)).scalar() == 0:
                        conn.execute(insert(students_table), DEMO_STUDENTS)
            print("Database ready.", flush=True)
            return
        except Exception as ex:
            print(f"DB not ready yet (attempt {attempt}/{retries}): {ex}", flush=True)
            if attempt < retries:
                time.sleep(delay_seconds)
    # The API still starts: every request that needs the database answers 500 with a hint.
    print("Database is not reachable – the API starts anyway, check the DB_* settings.", flush=True)


def _to_json(row) -> dict:
    return {COLUMNS[key]: value for key, value in row._mapping.items()}


def _to_columns(student: dict) -> dict:
    """{'firstName': ...} → {'FirstName': ...} (the id is never written)."""
    return {col: student[field] for col, field in COLUMNS.items() if col != "Id"}


# ── Repository: all SQL of the API ────────────────────────────────────────────

def all_students() -> list[dict]:
    with engine.connect() as conn:
        rows = conn.execute(select(students_table).order_by(students_table.c.Id))
        return [_to_json(r) for r in rows]


def find_student(student_id: int) -> dict | None:
    with engine.connect() as conn:
        row = conn.execute(select(students_table).where(students_table.c.Id == student_id)).first()
        return _to_json(row) if row else None


def create_student(student: dict) -> dict:
    with engine.begin() as conn:
        result = conn.execute(insert(students_table).values(**_to_columns(student)))
        new_id = result.inserted_primary_key[0]
    return find_student(new_id)


def update_student(student_id: int, student: dict) -> dict | None:
    with engine.begin() as conn:
        result = conn.execute(update(students_table)
                              .where(students_table.c.Id == student_id)
                              .values(**_to_columns(student)))
        if result.rowcount == 0:
            # MySQL reports 0 changed rows when the new values equal the old ones – check that the row exists
            if conn.execute(select(students_table.c.Id).where(students_table.c.Id == student_id)).first() is None:
                return None
    return find_student(student_id)


def delete_student(student_id: int) -> bool:
    with engine.begin() as conn:
        return conn.execute(delete(students_table).where(students_table.c.Id == student_id)).rowcount > 0
