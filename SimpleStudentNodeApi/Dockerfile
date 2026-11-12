# SimpleStudentNodeApi – Node.js 22 LTS + Express
# Both database drivers are pure npm packages (mssql/tedious and pg) – no system drivers needed,
# so the image is small and builds natively on Intel and Apple Silicon.
# The database is chosen at run time with DB_DRIVER (see docker-compose.yml / src/config.js).
FROM node:22-alpine

WORKDIR /app

# Install the packages first – Docker caches this layer, so code changes rebuild fast
COPY package.json package-lock.json* ./
RUN npm install --omit=dev --no-audit --no-fund

# The same folder you run locally with "npm start"
COPY . .

# Release version shown in GET /api/info – the CI/CD pipeline passes it with --build-arg
ARG APP_VERSION=1.2
ENV APP_VERSION=$APP_VERSION \
    NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=8080

# COPY keeps the file permissions from your computer; make sure the "node" user can read everything
RUN chmod -R a+rX /app
USER node

EXPOSE 8080
CMD ["node", "src/server.js"]
