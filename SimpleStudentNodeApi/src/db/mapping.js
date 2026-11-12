/* Shared by sqlsrv.js and postgres.js */

// Column name in the database  <->  field name in the JSON (camelCase, as in .NET, PHP and Python)
export const COLUMNS = {
    Id: 'id', FirstName: 'firstName', LastName: 'lastName', Email: 'email',
    StudyProgram: 'studyProgram', EnrollmentYear: 'enrollmentYear',
};

/** {Id: 1, FirstName: 'Jonas', ...} → {id: 1, firstName: 'Jonas', ...} */
export const toJson = (row) =>
    Object.fromEntries(Object.entries(COLUMNS).map(([column, field]) => [field, row[column]]));
