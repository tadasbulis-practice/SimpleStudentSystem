/*
 * Start-up: prepare the database, then listen.
 *
 *   npm install                  (once)
 *   npm start                    → http://localhost:6004/swagger
 *   Docker: docker-compose up --build   → http://localhost:6004/swagger (SQL Server)
 *                                        → http://localhost:6005/swagger (PostgreSQL)
 */

import { config } from './config.js';
import { prepareWithRetry } from './db/index.js';
import { app } from './app.js';

await prepareWithRetry();

app.listen(config.port, config.host, () => {
    const shown = config.host === '0.0.0.0' ? 'localhost' : config.host;
    console.log(`SimpleStudentNodeApi (${config.environment}, database: ${config.db.driver}) ` +
                `listening on http://${shown}:${config.port}/swagger`);
});
