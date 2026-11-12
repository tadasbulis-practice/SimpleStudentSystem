/*
 * Validation driven by the contract (contract-first, like the PHP API):
 * the rules are read from components.schemas.Student in openapi/openapi.json –
 * required, maxLength, format: email, minimum / maximum, readOnly.
 * Change a rule in openapi.json and both Swagger UI and this validator follow it.
 *
 * The messages are the same as StudentValidator in the .NET API, so every API
 * answers an invalid request with an identical 400 response.
 */

const MESSAGES = {
    firstName:      'First name is required.',
    lastName:       'Last name is required.',
    email:          'A valid email is required.',
    studyProgram:   'Study program is required.',
    enrollmentYear: 'Enrollment year must be between 2000 and 2100.',
};

/** "studyProgram" → "Study program" */
const label = (field) => {
    const words = field.replace(/([A-Z])/g, ' $1').trim().toLowerCase();
    return words.charAt(0).toUpperCase() + words.slice(1);
};

export class StudentValidator {
    /** @param {object} schema – components.schemas.Student from openapi.json */
    constructor(schema) {
        this.schema = schema;
        this.required = new Set(schema.required ?? []);
        // Fields a client may write (readOnly fields such as "id" are ignored)
        this.fields = Object.entries(schema.properties).filter(([, rules]) => !rules.readOnly);
    }

    /**
     * @returns {{ errors: Record<string, string[]>, student: object }}
     *          errors – empty when the body is valid; student – only the writable fields
     */
    validate(body) {
        const errors = {};
        const student = {};
        const add = (field, message) => (errors[field] ??= []).includes(message) || errors[field].push(message);

        for (const [field, rules] of this.fields) {
            const value = body[field];

            if (rules.type === 'string') {
                if (typeof value !== 'string' || value.trim() === '') {
                    if (this.required.has(field)) add(field, MESSAGES[field] ?? `${label(field)} is required.`);
                    student[field] = typeof value === 'string' ? value : null;
                    continue;
                }
                if (rules.maxLength !== undefined && value.length > rules.maxLength)
                    add(field, `${label(field)} must be at most ${rules.maxLength} characters.`);
                if (rules.format === 'email' && !value.includes('@'))
                    add(field, MESSAGES[field] ?? `${label(field)} must be an email address.`);
                student[field] = value;
            }

            if (rules.type === 'integer') {
                // A missing number becomes 0 in C# – and 0 is then outside the allowed range
                const number = value === undefined || value === null ? 0 : value;
                if (!Number.isInteger(number)) {
                    add(field, MESSAGES[field] ?? `${label(field)} must be a whole number.`);
                    continue;
                }
                if ((rules.minimum !== undefined && number < rules.minimum) ||
                    (rules.maximum !== undefined && number > rules.maximum))
                    add(field, MESSAGES[field] ?? `${label(field)} must be between ${rules.minimum} and ${rules.maximum}.`);
                student[field] = number;
            }
        }
        return { errors, student };
    }
}
