# PHP 8.3 + Apache – serves exactly the same folder you would copy into XAMPP's htdocs.
FROM php:8.3-apache

COPY . /var/www/html/

# COPY keeps the file permissions from your computer. If the files are readable only by
# their owner (e.g. -rw-------), Apache (user www-data) answers "Permission denied" / 403.
RUN find /var/www/html -type d -exec chmod 755 {} + \
 && find /var/www/html -type f -exec chmod 644 {} +

EXPOSE 80
