# SimpleStudentPythonApi – Python 3.12 + FastAPI + uvicorn
# Drivers for BOTH databases are pure pip packages (no system drivers needed):
#   pymssql (Microsoft SQL Server)  and  PyMySQL (MySQL / MariaDB)
# The database is chosen at run time with DB_DRIVER (see docker-compose.yml / config.py).
FROM python:3.12-slim

WORKDIR /app

# Install the packages first – Docker caches this layer, so code changes rebuild fast
COPY requirements.txt requirements-mssql.txt ./
RUN pip install --no-cache-dir -r requirements-mssql.txt

# The same folder you run locally with "python main.py"
COPY . .

EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
