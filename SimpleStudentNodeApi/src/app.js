/*
 * SimpleStudentNodeApi – the same Students REST API as SimpleStudentApi (.NET),
 * SimpleStudentPhpApi and SimpleStudentPythonApi, written in Node.js with Express.
 *
 *   Contract:  openapi/openapi.json – written by hand (contract-first, like the PHP API)
 *              served at /swagger/v1/swagger.json – the same URL as the other three APIs
 *   Swagger:   /swagger   (swagger-ui-express)
 *   Database:  SQL Server or PostgreSQL – chosen with DB_DRIVER (src/config.js)
 */

import { readFileSync } from 'node:fs';
import express from 'express';
import cors from 'cors';
import swaggerUi from 'swagger-ui-express';

import { config } from './config.js';
import { db } from './db/index.js';
import { sendProblem, sendValidationProblem } from './problems.js';
import { StudentValidator } from './validator.js';

// ── Contract ──────────────────────────────────────────────────────────────────
const contract = JSON.parse(readFileSync(new URL('../openapi/openapi.json', import.meta.url), 'utf8'));
const validator = new StudentValidator(contract.components.schemas.Student);

export const app = express();
app.disable('x-powered-by');

// Browser apps on other origins (Blazor WebAssembly, JavaScript frontends) may call the API
app.use(cors({ exposedHeaders: ['Location'] }));
app.use(express.json());

// ── Swagger UI ────────────────────────────────────────────────────────────────
app.get('/', (req, res) => res.redirect('/swagger'));
app.get('/swagger/v1/swagger.json', (req, res) => res.json(contract));
app.use('/swagger', swaggerUi.serve, swaggerUi.setup(null, {
    customSiteTitle: 'SimpleStudentNodeApi – Swagger',
    customCss: '.swagger-ui .topbar { background: #3c873a; } .swagger-ui .topbar .download-url-wrapper { display: none; }',
    swaggerOptions: { url: '/swagger/v1/swagger.json' },
}));

// ── Info ──────────────────────────────────────────────────────────────────────
app.get('/api/info', (req, res) => {
    res.json({
        service:      'SimpleStudentNodeApi',
        version:      config.version,
        status:       'ok',
        message:      `Student CRUD API in Node.js ${process.version} + Express (database: ${config.db.driver})`,
        environment:  config.environment,
        endpoints:    ['/api/students', '/api/students/{id}', '/api/faculty', '/swagger'],
        timestampUtc: new Date().toISOString(),
    });
});

// ── Students CRUD ─────────────────────────────────────────────────────────────

/** "/api/students/5" → 5. Like the .NET route {id:int}: anything that is not an int32 is "no such endpoint". */
function parseId(req, res) {
    const id = Number(req.params.id);
    if (!/^-?\d+$/.test(req.params.id) || id < -2147483648 || id > 2147483647) {
        sendProblem(res, 404, `No endpoint ${req.method} ${req.path}`, { detail: 'See /swagger for all endpoints.' });
        return null;
    }
    return id;
}

/** Validates the JSON body; sends 400 and returns null when it is not valid. */
function readStudent(req, res) {
    if (req.body === null || typeof req.body !== 'object' || Array.isArray(req.body)) {
        sendProblem(res, 400, 'The request body must be a JSON object.');
        return null;
    }
    const { errors, student } = validator.validate(req.body);
    if (Object.keys(errors).length > 0) {
        sendValidationProblem(res, errors);
        return null;
    }
    return student;
}

app.get('/api/students', async (req, res) => {
    res.json(await db.all());
});

app.get('/api/students/:id', async (req, res) => {
    const id = parseId(req, res);
    if (id === null) return;
    const student = await db.find(id);
    student ? res.json(student) : sendProblem(res, 404, 'Not Found');
});

app.post('/api/students', async (req, res) => {
    const student = readStudent(req, res);
    if (!student) return;
    const created = await db.create(student);          // the id in the body is ignored
    res.status(201).location(`/api/students/${created.id}`).json(created);
});

app.put('/api/students/:id', async (req, res) => {
    const id = parseId(req, res);
    if (id === null) return;
    const student = readStudent(req, res);
    if (!student) return;
    const updated = await db.update(id, student);
    updated ? res.json(updated) : sendProblem(res, 404, 'Not Found');
});

app.delete('/api/students/:id', async (req, res) => {
    const id = parseId(req, res);
    if (id === null) return;
    (await db.remove(id)) ? res.status(204).end() : sendProblem(res, 404, 'Not Found');
});

// ── Faculty hierarchy ─────────────────────────────────────────────────────────

/** "Computer Science", 2024 → "CS-24" (same rule as the .NET, PHP and Python APIs) */
const groupCode = (studyProgram, year) =>
    studyProgram.split(/\s+/).filter(Boolean).map((w) => w[0].toUpperCase()).join('') +
    '-' + String(year % 100).padStart(2, '0');

const byText = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

app.get('/api/faculty', async (req, res) => {
    const groups = new Map();
    for (const s of await db.all()) {
        const key = `${s.studyProgram}\u0000${s.enrollmentYear}`;
        if (!groups.has(key)) groups.set(key, { studyProgram: s.studyProgram, enrollmentYear: s.enrollmentYear, students: [] });
        groups.get(key).students.push(s);
    }
    res.json({
        name: 'Faculty of Technology',
        groups: [...groups.values()]
            .sort((a, b) => byText(a.studyProgram, b.studyProgram) || a.enrollmentYear - b.enrollmentYear)
            .map((g) => ({
                code:           groupCode(g.studyProgram, g.enrollmentYear),
                studyProgram:   g.studyProgram,
                enrollmentYear: g.enrollmentYear,
                students:       g.students.sort((a, b) => byText(a.lastName, b.lastName) || byText(a.firstName, b.firstName)),
            })),
    });
});

// ── Errors: the same problem+json format as the other APIs ────────────────────
const KNOWN_PATHS = [/^\/api\/info$/, /^\/api\/students$/, /^\/api\/students\/[^/]+$/, /^\/api\/faculty$/];

app.use((req, res) => {
    const known = KNOWN_PATHS.some((p) => p.test(req.path));
    known
        ? sendProblem(res, 405, `Method ${req.method} is not allowed for ${req.path}`, { detail: 'See /swagger for all endpoints.' })
        : sendProblem(res, 404, `No endpoint ${req.method} ${req.path}`, { detail: 'See /swagger for all endpoints.' });
});

// Express 5 sends errors thrown in async handlers here automatically
app.use((err, req, res, next) => {
    if (err.type === 'entity.parse.failed') return sendProblem(res, 400, 'The request body must be a JSON object.');
    console.error(err);
    // pg errors carry a code (SQLSTATE or ECONNREFUSED ...), mssql errors are ConnectionError / RequestError
    const isDb = err.code !== undefined || /^(Connection|Request|Transaction)Error$/.test(err.name);
    const hint = 'Check the DB_* settings (.env / docker-compose.yml / hosting dashboard) and that the database server is running.';
    if (isDb) return sendProblem(res, 500, 'Database error', config.debug ? { detail: err.message, hint } : {});
    sendProblem(res, 500, 'Server error', config.debug ? { detail: err.message } : {});
});
