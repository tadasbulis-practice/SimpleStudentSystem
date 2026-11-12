-- OPTIONAL: a separate MySQL user for the API instead of root.
-- Run after create.sql, then set 'user' and 'password' in config.php.

CREATE USER IF NOT EXISTS 'student_api'@'localhost' IDENTIFIED BY 'StudentApi*2026';
CREATE USER IF NOT EXISTS 'student_api'@'%'         IDENTIFIED BY 'StudentApi*2026';   -- for Docker → XAMPP

GRANT SELECT, INSERT, UPDATE, DELETE ON StudentDb.* TO 'student_api'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON StudentDb.* TO 'student_api'@'%';
FLUSH PRIVILEGES;
