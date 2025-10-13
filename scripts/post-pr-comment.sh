#!/bin/bash
# Script para publicar comentarios en Azure DevOps PR
# Uso: ./post-pr-comment.sh <ReportPath> <OrgUrl> <Project> <RepoId> <PrId>
# Nota: Requiere AZURE_DEVOPS_EXT_PAT como variable de entorno

set -e

# Validar argumentos
if [ $# -ne 5 ]; then
    echo "Uso: $0 <ReportPath> <OrgUrl> <Project> <RepoId> <PrId>"
    echo "Ejemplo: $0 report.md https://dev.azure.com/org/ MyProject repo-id 123"
    echo "Nota: AZURE_DEVOPS_EXT_PAT debe estar configurado como variable de entorno"
    exit 1
fi

REPORT_PATH=$1
ORG_URL=$2
PROJECT=$3
REPO_ID=$4
PR_ID=$5

# Verificar que el PAT está configurado
if [ -z "$AZURE_DEVOPS_EXT_PAT" ]; then
    echo "❌ Error: AZURE_DEVOPS_EXT_PAT environment variable is not set"
    exit 1
fi

# Verificar que el archivo de reporte existe
if [ ! -f "$REPORT_PATH" ]; then
    echo "❌ Error: No se encontró el archivo de reporte: $REPORT_PATH"
    exit 1
fi

# Leer el contenido del reporte
REPORT_CONTENT=$(cat "$REPORT_PATH")

# Configurar la URL de la API
API_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}/threads?api-version=7.0"

# Escapar el contenido para JSON (reemplazar comillas y nuevas líneas)
ESCAPED_CONTENT=$(echo "$REPORT_CONTENT" | jq -Rs .)

# Crear el cuerpo del comentario en JSON
JSON_BODY=$(cat <<EOF
{
  "comments": [
    {
      "parentCommentId": 0,
      "content": $ESCAPED_CONTENT,
      "commentType": 1
    }
  ],
  "status": 1
}
EOF
)

# Publicar el comentario
echo "Publicando comentario en la PR #$PR_ID..."

# Codificar PAT en Base64 para autenticación Basic (formato :PAT)
AUTH_HEADER="Authorization: Basic $(echo -n ":$AZURE_DEVOPS_EXT_PAT" | base64)"

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -H "$AUTH_HEADER" \
  -d "$JSON_BODY")

# Separar el cuerpo de la respuesta del código HTTP
HTTP_BODY=$(echo "$HTTP_RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n 1)

# Verificar el código de respuesta
if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    THREAD_ID=$(echo "$HTTP_BODY" | jq -r '.id // "unknown"')
    echo "✅ Comentario publicado exitosamente"
    echo "Thread ID: $THREAD_ID"
    exit 0
else
    echo "❌ Error al publicar comentario"
    echo "URL: $API_URL"
    echo "Status Code: $HTTP_CODE"
    echo "Response: $HTTP_BODY"
    exit 1
fi
