# PostgreSQL 17 with the lab's table and demo data built in.
# create.sql runs automatically on the first start (empty volume) – see docker-compose.postgres.yml.
FROM postgres:17-alpine

COPY create.sql /docker-entrypoint-initdb.d/create.sql

# COPY keeps the file permissions from your computer (on macOS often -rw-------);
# the init script is run by the user "postgres", so it must be readable for everyone.
RUN chmod 644 /docker-entrypoint-initdb.d/create.sql
