/*
 * SimpleStudent API as a Supabase Edge Function – the same Students REST contract as
 * SimpleStudentNodeApi (Node.js + Express), .NET, PHP and Python APIs, running INSIDE Supabase.
 *
 *   URL:       https://<project-ref>.supabase.co/functions/v1/simplestudent-api/api/students
 *   Contract:  ./openapi.json  (a copy of SimpleStudentNodeApi/openapi/openapi.json – keep them identical,
 *              CI checks it)  served at  .../simplestudent-api/swagger/v1/swagger.json
 *   Swagger UI: Edge Functions may not return HTML, so Swagger UI is a static page on GitHub Pages
 *              (folder swagger-ui/ of the repository) that loads the contract from here.
 *   Database:  the project's own PostgreSQL – SUPABASE_DB_URL is provided by Supabase automatically.
 *
 * What is different from the Node.js API (compare with SimpleStudentNodeApi/src/app.js):
 *   - runtime is Deno (Supabase Edge Runtime), npm packages are imported with "npm:name@version"
 *   - every path starts with the function name: /simplestudent-api/...
 *   - no Docker, no hosting dashboard: `supabase functions deploy` (GitHub Actions does it)
 *   - settings (APP_ENVIRONMENT, APP_VERSION, API_READ_ONLY) are Edge Function secrets,
 *     set by the workflow with `supabase secrets set`
 *
 * Local run (Supabase CLI + Docker):  supabase start && supabase functions serve
 *   → http://localhost:54321/functions/v1/simplestudent-api/api/info
 */

// @ts-types="npm:@types/express@4.17.21"
import express, { type NextFunction, type Request, type Response } from 'npm:express@4.21.2';
// @ts-types="npm:@types/cors@2.8.17"
import cors from 'npm:cors@2.8.5';

import contractFile from './openapi.json' with { type: 'json' };
import { sendProblem, sendValidationProblem } from './problems.js';
import { StudentValidator } from './validator.js';
import { db } from './db.ts';

const FUNCTION_NAME = 'simplestudent-api';

const env = (name: string, fallback: string) => Deno.env.get(name) || fallback;
const config = {
    environment: env('APP_ENVIRONMENT', 'Development'),          // Test / Production (set by the workflow)
    version:     env('APP_VERSION', 'local'),                     // release version (set by the workflow)
    readOnly:    env('API_READ_ONLY', 'false') === 'true',        // true → POST / PUT / DELETE answer 403
    debug:       env('APP_DEBUG', 'false') === 'true',            // true → error responses include the DB message
    swaggerUi:   env('SWAGGER_UI_URL', ''),                       // GitHub Pages address (set by the workflow)
    supabaseUrl: env('SUPABASE_URL', ''),                         // https://<ref>.supabase.co (provided by Supabase)
};

/** Public address of this function, e.g. https://abc.supabase.co/functions/v1/simplestudent-api */
function publicBase(req: Request): string {
    if (config.supabaseUrl.startsWith('https://')) return `${config.supabaseUrl}/functions/v1/${FUNCTION_NAME}`;
    return `${req.protocol}://${req.get('host')}${req.baseUrl}`;   // local run
}

// ── Contract ──────────────────────────────────────────────────────────────────
// deno-lint-ignore no-explicit-any
const contract = contractFile as any;
const validator = new StudentValidator(contract.components.schemas.Student);

const api = express.Router();
api.use(express.json());        // inside the router, so invalid JSON reaches the error handler below

// ── Swagger ───────────────────────────────────────────────────────────────────
api.get('/swagger/v1/swagger.json', (req, res) => {
    // servers = this function, so "Try it out" in Swagger UI (GitHub Pages) calls the right environment
    res.json({
        ...contract,
        info: { ...contract.info, title: 'SimpleStudent Edge API (Supabase)', 'x-environment': config.environment },
        servers: [{ url: publicBase(req), description: `Supabase Edge Function – ${config.environment}` }],
    });
});

const swaggerHint = (req: Request, res: Response) => res.json({
    message: 'Edge Functions cannot serve HTML pages. Open Swagger UI on GitHub Pages, it loads the contract from openapi.',
    swaggerUi: config.swaggerUi || null,
    openapi: `${publicBase(req)}/swagger/v1/swagger.json`,
});
api.get('/', swaggerHint);
api.get('/swagger', swaggerHint);

// ── Info ──────────────────────────────────────────────────────────────────────
api.get('/api/info', (_req, res) => {
    res.json({
        service:      'SimpleStudentEdgeApi',
        version:      config.version,
        status:       'ok',
        message:      `Student CRUD API in Supabase Edge Functions (Deno ${Deno.version.deno}) + Express (database: Supabase PostgreSQL)`,
        environment:  config.environment,
        readOnly:     config.readOnly,
        endpoints:    ['/api/students', '/api/students/{id}', '/api/faculty', '/swagger/v1/swagger.json'],
        timestampUtc: new Date().toISOString(),
    });
});

// ── Helpers ───────────────────────────────────────────────────────────────────
/** Express 4 does not catch errors of async handlers – this passes them to the error handler below. */
type Handler = (req: Request, res: Response) => Promise<unknown>;
const ah = (fn: Handler) => (req: Request, res: Response, next: NextFunction) => fn(req, res).catch(next);

/** "/api/students/5" → 5. Like the .NET route {id:int}: anything that is not an int32 is "no such endpoint". */
function parseId(req: Request, res: Response): number | null {
    const id = Number(req.params.id);
    if (!/^-?\d+$/.test(req.params.id) || id < -2147483648 || id > 2147483647) {
        sendProblem(res, 404, `No endpoint ${req.method} ${req.path}`, { detail: 'See /swagger/v1/swagger.json for all endpoints.' });
        return null;
    }
    return id;
}

/** Validates the JSON body; sends 400 and returns null when it is not valid. */
// deno-lint-ignore no-explicit-any
function readStudent(req: Request, res: Response): any | null {
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

/** API_READ_ONLY=true (e.g. Production for students): reading works, changing answers 403. */
function writeAllowed(res: Response): boolean {
    if (!config.readOnly) return true;
    sendProblem(res, 403, 'This environment is read-only.', {
        detail: `POST, PUT and DELETE are disabled in ${config.environment} (API_READ_ONLY=true). Use the Test environment.`,
    });
    return false;
}

// ── Students CRUD ─────────────────────────────────────────────────────────────
api.get('/api/students', ah(async (_req, res) => {
    res.json(await db.all());
}));

api.get('/api/students/:id', ah(async (req, res) => {
    const id = parseId(req, res);
    if (id === null) return;
    const student = await db.find(id);
    student ? res.json(student) : sendProblem(res, 404, 'Not Found');
}));

api.post('/api/students', ah(async (req, res) => {
    if (!writeAllowed(res)) return;
    const student = readStudent(req, res);
    if (!student) return;
    const created = await db.create(student);          // the id in the body is ignored
    res.status(201).location(`${publicBase(req)}/api/students/${created.id}`).json(created);
}));

api.put('/api/students/:id', ah(async (req, res) => {
    if (!writeAllowed(res)) return;
    const id = parseId(req, res);
    if (id === null) return;
    const student = readStudent(req, res);
    if (!student) return;
    const updated = await db.update(id, student);
    updated ? res.json(updated) : sendProblem(res, 404, 'Not Found');
}));

api.delete('/api/students/:id', ah(async (req, res) => {
    if (!writeAllowed(res)) return;
    const id = parseId(req, res);
    if (id === null) return;
    (await db.remove(id)) ? res.status(204).end() : sendProblem(res, 404, 'Not Found');
}));

// ── Faculty hierarchy ─────────────────────────────────────────────────────────
/** "Computer Science", 2024 → "CS-24" (same rule as the .NET, PHP, Python and Node.js APIs) */
const groupCode = (studyProgram: string, year: number) =>
    studyProgram.split(/\s+/).filter(Boolean).map((w) => w[0].toUpperCase()).join('') +
    '-' + String(year % 100).padStart(2, '0');

const byText = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);

api.get('/api/faculty', ah(async (_req, res) => {
    // deno-lint-ignore no-explicit-any
    const groups = new Map<string, any>();
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
                // deno-lint-ignore no-explicit-any
                students:       g.students.sort((a: any, b: any) => byText(a.lastName, b.lastName) || byText(a.firstName, b.firstName)),
            })),
    });
}));

// ── Errors: the same problem+json format as the other APIs ────────────────────
const KNOWN_PATHS = [/^\/api\/info$/, /^\/api\/students$/, /^\/api\/students\/[^/]+$/, /^\/api\/faculty$/];

api.use((req, res) => {
    const known = KNOWN_PATHS.some((p) => p.test(req.path));
    known
        ? sendProblem(res, 405, `Method ${req.method} is not allowed for ${req.path}`, { detail: 'See /swagger/v1/swagger.json for all endpoints.' })
        : sendProblem(res, 404, `No endpoint ${req.method} ${req.path}`, { detail: 'See /swagger/v1/swagger.json for all endpoints.' });
});

// deno-lint-ignore no-explicit-any
api.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
    if (err?.type === 'entity.parse.failed') return sendProblem(res, 400, 'The request body is not valid JSON.');
    console.error(err);
    sendProblem(res, 500, 'Database error', config.debug ? { detail: String(err?.message ?? err) } : {});
});

// ── App ───────────────────────────────────────────────────────────────────────
const app = express();
app.disable('x-powered-by');
// Browser apps on other origins (Swagger UI on GitHub Pages, Blazor WebAssembly, JavaScript frontends)
app.use(cors({ exposedHeaders: ['Location'] }));
app.use(`/${FUNCTION_NAME}`, api);          // Supabase calls the function with /simplestudent-api/...

app.listen(Number(env('PORT', '8000')));
