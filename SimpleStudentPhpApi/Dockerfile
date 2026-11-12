# SimpleStudentPhpApi – PHP 8.3 + Apache with drivers for BOTH databases:
#   pdo_sqlsrv (Microsoft SQL Server)  and  pdo_mysql (MySQL / MariaDB)
# The database is chosen at run time with DB_DRIVER (see docker-compose.yml / config.php).
FROM php:8.3-apache-bookworm

# Microsoft ODBC Driver 18 + PHP extension pdo_sqlsrv (from PECL), pdo_mysql, mod_rewrite
RUN apt-get update \
 && apt-get install -y --no-install-recommends gnupg curl ca-certificates unixodbc-dev $PHPIZE_DEPS \
 && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
 && curl -fsSL https://packages.microsoft.com/config/debian/12/prod.list \
      -o /etc/apt/sources.list.d/mssql-release.list \
 && apt-get update \
 && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 \
 && pecl install pdo_sqlsrv \
 && docker-php-ext-enable pdo_sqlsrv \
 && docker-php-ext-install pdo_mysql \
 && a2enmod rewrite \
 && apt-get purge -y --auto-remove $PHPIZE_DEPS \
 && rm -rf /var/lib/apt/lists/* /tmp/pear

# The same folder you would copy into XAMPP's htdocs
COPY . /var/www/html/

# COPY keeps the file permissions from your computer; make sure Apache (www-data) can read everything
RUN find /var/www/html -type d -exec chmod 755 {} + \
 && find /var/www/html -type f -exec chmod 644 {} +

EXPOSE 80
