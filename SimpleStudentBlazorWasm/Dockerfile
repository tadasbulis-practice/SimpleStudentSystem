# Build: .NET SDK compiles the app to static files (wwwroot + _framework/*.wasm, *.dll)
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Run: only a static web server – no .NET runtime on the server side
FROM nginx:alpine AS final
COPY --from=build /app/publish/wwwroot /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
# nginx worker runs as user 'nginx': make sure it can read every file (fixes 403 Forbidden
# when the source files on the host are not world-readable, e.g. mode 600)
RUN chmod -R a+rX /usr/share/nginx/html && chmod a+r /etc/nginx/conf.d/default.conf
EXPOSE 80
