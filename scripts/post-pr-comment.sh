#!/bin/bash

# Script para publicar comentario de revisión en Pull Request de Azure DevOps
# Uso: ./post-pr-comment.sh <COMMENT_FILE> <ORGANIZATION> <PROJECT> <REPOSITORY> <PR_ID> <PAT>

echo "💬 Publicar comentario en Pull Request de Azure DevOps"
echo "===================================================="

# Verificar parámetros
if [ $# -ne 6 ]; then
    echo "❌ ERROR: Número incorrecto de parámetros"
    echo "Uso: $0 <COMMENT_FILE> <ORGANIZATION> <PROJECT> <REPOSITORY> <PR_ID> <PAT>"
    echo ""
    echo "Ejemplo:"
    echo "$0 'pr-comment.md' 'returngisorg' 'GitHub Copilot CLI' 'Demo' '123' 'your-pat'"
    echo ""
    echo "Parámetros:"
    echo "  COMMENT_FILE:  Archivo markdown con el comentario a publicar"
    echo "  ORGANIZATION:  Organización de Azure DevOps"
    echo "  PROJECT:       Nombre del proyecto"
    echo "  REPOSITORY:    Nombre del repositorio"
    echo "  PR_ID:         ID numérico del Pull Request"
    echo "  PAT:           Personal Access Token con permisos de contribuir a PRs"
    exit 1
fi

# Asignar parámetros
COMMENT_FILE="$1"
ORGANIZATION="$2"
PROJECT="$3"
REPOSITORY="$4"
PR_ID="$5"
PAT="$6"

echo "📋 Configuración:"
echo "  - Archivo de comentario: $COMMENT_FILE"
echo "  - Organización: $ORGANIZATION"
echo "  - Proyecto: $PROJECT"
echo "  - Repositorio: $REPOSITORY"
echo "  - PR ID: $PR_ID"
echo ""

# Verificar que existe el archivo de comentario
if [ ! -f "$COMMENT_FILE" ]; then
    echo "❌ ERROR: No se encuentra el archivo $COMMENT_FILE"
    exit 1
fi

# Verificar que el archivo no está vacío
if [ ! -s "$COMMENT_FILE" ]; then
    echo "❌ ERROR: El archivo $COMMENT_FILE está vacío"
    exit 1
fi

# Codificar el proyecto para la URL
PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/ /%20/g')

# Construir la URL de la API
API_URL="https://dev.azure.com/$ORGANIZATION/$PROJECT_ENCODED/_apis/git/repositories/$REPOSITORY/pullRequests/$PR_ID/threads?api-version=7.1"
echo "🔗 API URL: $API_URL"

# Leer el contenido del archivo y prepararlo para JSON
echo "📖 Leyendo contenido del comentario..."
COMMENT_CONTENT=$(cat "$COMMENT_FILE")
COMMENT_SIZE=$(wc -c < "$COMMENT_FILE")
echo "📊 Tamaño del comentario: $COMMENT_SIZE bytes"

# Crear el payload JSON usando el método que funciona en test-pr-comment.sh
echo "🔧 Using manual JSON escaping (same method as test script)..."
# Escapar contenido para JSON - método simple y confiable
ESCAPED_CONTENT=$(printf '%s' "$COMMENT_CONTENT" | \
    sed 's/\\/\\\\/g' | \
    sed 's/"/\\"/g' | \
    awk '{printf "%s\\n", $0}' | \
    sed 's/\\n$//')

# Crear archivo temporal con el payload
PAYLOAD_FILE="/tmp/pr-comment-payload-$$.json"
cat > "$PAYLOAD_FILE" << EOF
{
  "comments": [
    {
      "parentCommentId": 0,
      "content": "$ESCAPED_CONTENT",
      "commentType": 1
    }
  ],
  "status": 1
}
EOF

echo "📝 Payload preparado en: $PAYLOAD_FILE"
echo "📊 Tamaño del payload: $(wc -c < "$PAYLOAD_FILE") bytes"

# Generar header de autenticación
AUTH_HEADER=$(printf "%s:" "$PAT" | base64)

echo ""
echo "🌐 Publicando comentario en la PR..."

# Debug: Show payload content (first 200 chars)
echo "🔍 Payload preview (first 200 chars):"
head -c 200 "$PAYLOAD_FILE"
echo ""
echo ""

# Debug: Show authentication header length (without exposing actual PAT)
echo "🔑 Auth header length: ${#AUTH_HEADER} characters"

# Test connectivity first
echo "🌐 Testing basic connectivity to Azure DevOps..."
CONNECTIVITY_TEST=$(curl -s -w "HTTPSTATUS:%{http_code}" -I "https://dev.azure.com/$ORGANIZATION" --connect-timeout 10)
CONNECT_CODE=$(echo "$CONNECTIVITY_TEST" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
echo "📡 Connectivity test result: $CONNECT_CODE"

# Realizar la llamada a la API (using exact same method as test script)
echo "🚀 Making API call..."
HTTP_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
  --connect-timeout 30 \
  --max-time 60 \
  -X POST \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d @"$PAYLOAD_FILE" \
  "$API_URL")

# Separar código HTTP del contenido
HTTP_CODE=$(echo "$HTTP_RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | sed 's/HTTPSTATUS:[0-9]*$//')

echo "📡 Código de respuesta HTTP: $HTTP_CODE"

# Debug: Show response details if HTTP_CODE is empty or 000
if [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" = "000" ]; then
    echo "🔍 DEBUG: Curl command failed or returned code 000"
    echo "🔍 Full response: $HTTP_RESPONSE"
    echo "🔍 Response length: ${#HTTP_RESPONSE} characters"
    
    # Check if curl is available and working
    if ! command -v curl &> /dev/null; then
        echo "❌ ERROR: curl command not found"
        exit 1
    fi
    
    # Try a simple test to see if curl can reach the internet
    echo "🌐 Testing basic internet connectivity..."
    if curl -s --connect-timeout 5 --head "https://httpbin.org/get" > /dev/null; then
        echo "✅ Internet connectivity works"
    else
        echo "❌ Internet connectivity failed"
    fi
fi

# Limpiar archivo temporal
rm -f "$PAYLOAD_FILE"

# Procesar la respuesta
case "$HTTP_CODE" in
    200|201)
        echo "✅ Comentario publicado exitosamente"
        
        # Extraer información del comentario si es posible
        if command -v jq &> /dev/null && echo "$RESPONSE_BODY" | jq empty 2>/dev/null; then
            THREAD_ID=$(echo "$RESPONSE_BODY" | jq -r '.id // "N/A"')
            COMMENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.comments[0].id // "N/A"')
            echo "📌 Thread ID: $THREAD_ID"
            echo "💬 Comment ID: $COMMENT_ID"
        fi
        
        # Construir URL del comentario
        PR_URL="https://dev.azure.com/$ORGANIZATION/$PROJECT_ENCODED/_git/$REPOSITORY/pullrequest/$PR_ID"
        echo ""
        echo "🔗 Ver comentario en: $PR_URL"
        echo ""
        echo "📊 Estadísticas:"
        echo "  - Líneas publicadas: $(echo "$COMMENT_CONTENT" | wc -l)"
        echo "  - Caracteres: $(echo "$COMMENT_CONTENT" | wc -c)"
        echo "  - Palabras: $(echo "$COMMENT_CONTENT" | wc -w)"
        ;;
    400)
        echo "❌ ERROR: Solicitud inválida (400)"
        echo "Posibles causas:"
        echo "  - Formato de JSON incorrecto"
        echo "  - Parámetros faltantes o inválidos"
        echo "  - PR ID no existe"
        if [ -n "$RESPONSE_BODY" ]; then
            echo ""
            echo "📋 Respuesta del servidor:"
            echo "$RESPONSE_BODY" | head -10
        fi
        exit 1
        ;;
    401)
        echo "❌ ERROR: No autorizado (401)"
        echo "Posibles causas:"
        echo "  - PAT inválido o expirado"
        echo "  - PAT sin permisos para contribuir a PRs"
        echo "  - Organización o proyecto incorrecto"
        exit 1
        ;;
    403)
        echo "❌ ERROR: Acceso denegado (403)"
        echo "Posibles causas:"
        echo "  - PAT sin permisos suficientes"
        echo "  - Usuario sin acceso al repositorio"
        echo "  - Políticas de rama que impiden comentarios"
        exit 1
        ;;
    404)
        echo "❌ ERROR: No encontrado (404)"
        echo "Posibles causas:"
        echo "  - PR ID no existe: $PR_ID"
        echo "  - Repositorio incorrecto: $REPOSITORY"
        echo "  - Proyecto incorrecto: $PROJECT"
        echo "  - Organización incorrecta: $ORGANIZATION"
        exit 1
        ;;
    *)
        echo "❌ ERROR: Código HTTP inesperado: $HTTP_CODE"
        if [ -n "$RESPONSE_BODY" ]; then
            echo ""
            echo "📋 Respuesta del servidor:"
            echo "$RESPONSE_BODY"
        fi
        exit 1
        ;;
esac

echo ""
echo "🎉 Comentario de revisión publicado exitosamente en la PR #$PR_ID"