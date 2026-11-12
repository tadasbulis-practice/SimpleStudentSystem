# Regenerates StudentApiClient.g.cs from the running API's Swagger document (Windows / PowerShell).
# 1) Start the API first (docker compose up, or dotnet run in SimpleStudentApi)
# 2) Run from this folder:  .\generate-client.ps1
# Needs Node.js (npx downloads NSwag automatically).
param([string]$SwaggerUrl = "http://localhost:6001/swagger/v1/swagger.json")
Invoke-WebRequest $SwaggerUrl -OutFile swagger.json      # keep a copy of the contract
npx --yes nswag@14 openapi2csclient /runtime:Net80 `
  /input:swagger.json `
  /output:StudentApiClient.g.cs `
  /namespace:SimpleStudentFrontend.ApiClient `
  /className:StudentApiClient `
  /jsonLibrary:SystemTextJson `
  /useBaseUrl:false `
  /generateClientInterfaces:true `
  /injectHttpClient:true `
  /disposeHttpClient:false `
  /operationGenerationMode:SingleClientFromOperationId
Write-Host "Done: StudentApiClient.g.cs regenerated."
