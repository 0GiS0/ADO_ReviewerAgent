#!/bin/bash
set -e

echo "📋 Getting changed files in PR using Azure DevOps REST API..."

# Variables de entorno requeridas
ORG_URL="${SYSTEM_COLLECTIONURI}"
PROJECT="${SYSTEM_TEAMPROJECT}"
REPO_ID="${BUILD_REPOSITORY_ID}"
PR_ID="${SYSTEM_PULLREQUEST_PULLREQUESTID}"

# Validar variables
if [ -z "$ORG_URL" ] || [ -z "$PROJECT" ] || [ -z "$REPO_ID" ] || [ -z "$PR_ID" ]; then
    echo "❌ Error: Variables de Azure DevOps no configuradas"
    echo "ORG_URL: $ORG_URL"
    echo "PROJECT: $PROJECT"
    echo "REPO_ID: $REPO_ID"
    echo "PR_ID: $PR_ID"
    exit 1
fi

echo "Repository: ${BUILD_REPOSITORY_NAME}"
echo "PR ID: $PR_ID"

# Usar la API de Azure DevOps para obtener los archivos cambiados
API_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}/iterations?api-version=7.0"

echo ""
echo "🌐 Fetching PR changes from Azure DevOps API..."

# Usar System.AccessToken si está disponible, o AZURE_DEVOPS_EXT_PAT
if [ -n "$SYSTEM_ACCESSTOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $SYSTEM_ACCESSTOKEN"
elif [ -n "$AZURE_DEVOPS_EXT_PAT" ]; then
    AUTH_HEADER="Authorization: Basic $(echo -n ":$AZURE_DEVOPS_EXT_PAT" | base64)"
else
    echo "❌ Error: No authentication token available"
    exit 1
fi

# Obtener las iteraciones de la PR
PR_DATA=$(curl -s -H "$AUTH_HEADER" "$API_URL")

# Obtener la última iteración
LATEST_ITERATION=$(echo "$PR_DATA" | jq -r '.value | sort_by(.id) | last | .id')

if [ -z "$LATEST_ITERATION" ] || [ "$LATEST_ITERATION" = "null" ]; then
    echo "❌ Error: Could not get PR iterations"
    exit 1
fi

echo "Latest iteration: $LATEST_ITERATION"

# Obtener los cambios de la iteración
CHANGES_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}/iterations/${LATEST_ITERATION}/changes?api-version=7.0"

echo "Fetching changes..."
CHANGES_DATA=$(curl -s -H "$AUTH_HEADER" "$CHANGES_URL")

# Extraer los nombres de archivos cambiados
echo "$CHANGES_DATA" | jq -r '.changeEntries[]? | select(.changeType != "delete") | .item.path' | sed 's/^\///' > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"

echo ""
echo "Archivos modificados:"
cat "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"

FILE_COUNT=$(wc -l < "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt" | tr -d ' ')
echo ""
echo "✅ $FILE_COUNT archivos modificados detectados"
