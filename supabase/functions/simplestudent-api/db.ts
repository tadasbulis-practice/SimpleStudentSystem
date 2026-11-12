/*
 * Database layer of the Edge Function – the same SQL as SimpleStudentNodeApi/src/db/postgres.js,
 * with the npm package "postgres" (postgres.js) that Supabase recommends for Edge Functions.
 *
 * SUPABASE_DB_URL is set by Supabase automatically (hosted and `supabase functions serve`).
 * The function connects as the table owner, so Row Level Security (no policies) does not block it.
 * The table itself is created by the migrations (supabase/migrations), not by this code.
 */

import postgres from 'npm:postgres@3.4.5';

const sql = postgres(Deno.env.get('SUPABASE_DB_URL')!, {
    prepare: false,     // required for the Supabase pooler in "transaction" mode
    max: 3,             // an Edge Function instance is small – a few connections are enough
});

export type Student = {
    id: number; firstName: string; lastName: string;
    email: string; studyProgram: string; enrollmentYear: number;
};

// Column name in the database  <->  field name in the JSON (camelCase, as in all the other APIs)
// deno-lint-ignore no-explicit-any
const toJson = (row: any): Student => ({
    id: row.Id, firstName: row.FirstName, lastName: row.LastName,
    email: row.Email, studyProgram: row.StudyProgram, enrollmentYear: row.EnrollmentYear,
});

type NewStudent = Omit<Student, 'id'>;

export const db = {
    async all(): Promise<Student[]> {
        const rows = await sql`SELECT * FROM "Students" ORDER BY "Id"`;
        return rows.map(toJson);
    },

    async find(id: number): Promise<Student | null> {
        const rows = await sql`SELECT * FROM "Students" WHERE "Id" = ${id}`;
        return rows[0] ? toJson(rows[0]) : null;
    },

    async create(s: NewStudent): Promise<Student> {
        const rows = await sql`
            INSERT INTO "Students" ("FirstName", "LastName", "Email", "StudyProgram", "EnrollmentYear")
            VALUES (${s.firstName}, ${s.lastName}, ${s.email}, ${s.studyProgram}, ${s.enrollmentYear})
            RETURNING *`;
        return toJson(rows[0]);
    },

    async update(id: number, s: NewStudent): Promise<Student | null> {
        const rows = await sql`
            UPDATE "Students"
            SET "FirstName" = ${s.firstName}, "LastName" = ${s.lastName}, "Email" = ${s.email},
                "StudyProgram" = ${s.studyProgram}, "EnrollmentYear" = ${s.enrollmentYear}
            WHERE "Id" = ${id}
            RETURNING *`;
        return rows[0] ? toJson(rows[0]) : null;
    },

    async remove(id: number): Promise<boolean> {
        const result = await sql`DELETE FROM "Students" WHERE "Id" = ${id}`;
        return result.count > 0;
    },
};
