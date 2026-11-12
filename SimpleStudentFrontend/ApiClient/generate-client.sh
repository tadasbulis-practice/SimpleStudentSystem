#!/usr/bin/env bash
# Regenerates StudentApiClient.g.cs from the running API's Swagger document.
# 1) Start the API first (docker compose up, or dotnet run in SimpleStudentApi)
# 2) Run from this folder:  bash generate-client.sh
# Needs Node.js (npx downloads NSwag automatically).
set -e
SWAGGER_URL="${1:-http://localhost:6001/swagger/v1/swagger.json}"
curl -s "$SWAGGER_URL" -o swagger.json        # keep a copy of the contract
npx --yes nswag@14 openapi2csclient /runtime:Net80 \
  /input:swagger.json \
  /output:StudentApiClient.g.cs \
  /namespace:SimpleStudentFrontend.ApiClient \
  /className:StudentApiClient \
  /jsonLibrary:SystemTextJson \
  /useBaseUrl:false \
  /generateClientInterfaces:true \
  /injectHttpClient:true \
  /disposeHttpClient:false \
  /operationGenerationMode:SingleClientFromOperationId
echo "Done: StudentApiClient.g.cs regenerated."
