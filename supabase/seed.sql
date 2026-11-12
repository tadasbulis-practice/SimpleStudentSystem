-- SimpleStudent – demo data
--
-- Local:  supabase db reset                       (migrations + this file)
-- Cloud:  supabase db push --include-seed         (GitHub Actions does it; Supabase runs a seed
--         file only once per project and re-runs it only when the file changes)
-- Only if the table is empty, so real data entered in Test / Production is never overwritten.

INSERT INTO "Students" ("FirstName", "LastName", "Email", "StudyProgram", "EnrollmentYear")
SELECT * FROM (VALUES
    ('Jonas', 'Jonaitis',     'jonas@kk.lt', 'Computer Science', 2024),
    ('Ieva',  'Kazlauskaitė', 'ieva@kk.lt',  'Computer Science', 2024),
    ('Amir',  'Haddad',       'amir@kk.lt',  'Software Systems', 2025)
) AS demo ("FirstName", "LastName", "Email", "StudyProgram", "EnrollmentYear")
WHERE NOT EXISTS (SELECT 1 FROM "Students");
