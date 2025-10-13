#!/bin/bash

# Script parametrizado para obtener diferencias de PR usando Azure DevOps API
# Uso: ./get-pr-diff.sh <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> <OUTPUT_FILE>

echo "🌐 Obtener diferencias de PR usando Azure DevOps API"
echo "==================================================="

# Verificar parámetros
if [ $# -ne 5 ]; then
    echo "❌ ERROR: Número incorrecto de parámetros"
    echo "Uso: $0 <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> <OUTPUT_FILE>"
    echo ""
    echo "Ejemplo:"
    echo "$0 'https://user@dev.azure.com/org/project/_git/repo' 'refs/heads/feature' 'refs/heads/main' 'your-pat' '/path/to/output.json'"
    exit 1
fi

# Asignar parámetros
SOURCE_REPO_URI="$1"
SOURCE_BRANCH="$2"
TARGET_BRANCH="$3"
PAT="$4"
OUTPUT_FILE="$5"

echo "📋 Información del PR:"
echo "  - Repository URI: $SOURCE_REPO_URI"
echo "  - Source Branch: $SOURCE_BRANCH"
echo "  - Target Branch: $TARGET_BRANCH"
echo "  - Output File: $OUTPUT_FILE"
echo ""

# Extraer información del repositorio
echo "🔍 Procesando URI del repositorio..."
TEMP_URI=$(echo $SOURCE_REPO_URI | sed 's|https://[^@]*@||')
echo "URI procesada: $TEMP_URI"

# Obtener la organización
ORG=$(echo $TEMP_URI | awk -F'/' '{print $2}')
echo "  - ORGANIZATION: $ORG"

# Obtener el proyecto (decodificar %20 a espacios)
PROJECT=$(echo $TEMP_URI | awk -F'/' '{print $3}' | sed 's/%20/ /g')
echo "  - PROJECT: $PROJECT"

# Obtener el repositorio
REPO=$(echo $TEMP_URI | awk -F'/' '{print $5}')
echo "  - REPOSITORY: $REPO"

# Limpiar prefijos refs/heads/ si existen
SOURCE_BRANCH_CLEAN=$(echo "$SOURCE_BRANCH" | sed 's|refs/heads/||')
TARGET_BRANCH_CLEAN=$(echo "$TARGET_BRANCH" | sed 's|refs/heads/||')

echo "  - SOURCE BRANCH: $SOURCE_BRANCH_CLEAN"
echo "  - TARGET BRANCH: $TARGET_BRANCH_CLEAN"

# Codificar el proyecto para la URL
PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/ /%20/g')

# Construir la URL de la API
API_URL="https://dev.azure.com/$ORG/$PROJECT_ENCODED/_apis/git/repositories/$REPO/diffs/commits"
echo "  - API URL: $API_URL"

# Parámetros de la API
PARAMS="baseVersion=$TARGET_BRANCH_CLEAN&targetVersion=$SOURCE_BRANCH_CLEAN&baseVersionType=branch&targetVersionType=branch&api-version=7.2-preview.1"
FULL_URL="$API_URL?$PARAMS"
echo "  - FULL URL: $FULL_URL"

echo ""
echo "🌐 Realizando llamada a la API..."

# Generar el header de autenticación Basic
echo "🔍 Debug PAT info:"
echo "  - PAT length: ${#PAT}"
echo "  - PAT first 4 chars: ${PAT:0:4}..."
echo "  - PAT last 4 chars: ...${PAT: -4}"

AUTH_HEADER=$(printf "%s:" "$PAT" | base64 -w 0)
echo "🔑 Header de autenticación generado (length: ${#AUTH_HEADER})"

# Realizar la llamada a la API
echo "📡 Ejecutando curl..."
echo "🔍 Debug curl - Headers y URL:"
echo "  - Authorization: Basic [HEADER_HIDDEN]"
echo "  - Content-Type: application/json"
echo "  - Accept: application/json"
echo "  - URL: $FULL_URL"

curl -v \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  "$FULL_URL" > "$OUTPUT_FILE" 2>&1 | tee /tmp/curl_debug.log

CURL_EXIT_CODE=$?
echo "🔍 Curl terminó con código: $CURL_EXIT_CODE"

if [ $CURL_EXIT_CODE -ne 0 ]; then
  echo "❌ ERROR: Curl falló con código $CURL_EXIT_CODE"
  echo "📋 Debug de curl:"
  cat /tmp/curl_debug.log
  exit 1
fi

# Verificar el resultado
echo ""
echo "📄 Verificando resultado..."

if [ -f "$OUTPUT_FILE" ]; then
  echo "✅ Archivo de respuesta creado: $OUTPUT_FILE"
  echo "📊 Tamaño: $(du -h "$OUTPUT_FILE" | cut -f1)"
  
  # Debug: Mostrar contenido del archivo
  echo "🔍 Debug - Contenido del archivo de respuesta:"
  if [ -s "$OUTPUT_FILE" ]; then
    echo "--- INICIO CONTENIDO ---"
    cat "$OUTPUT_FILE"
    echo "--- FIN CONTENIDO ---"
  else
    echo "⚠️  ARCHIVO VACÍO (0 bytes)"
    echo "📋 Debug de curl completo:"
    if [ -f /tmp/curl_debug.log ]; then
      cat /tmp/curl_debug.log
    else
      echo "No se encontró log de debug de curl"
    fi
  fi
  
  # Verificar si es JSON válido
  if command -v jq &> /dev/null; then
    if jq empty "$OUTPUT_FILE" 2>/dev/null; then
      echo "✅ JSON válido recibido"
      
      # Extraer estadísticas
      CHANGE_COUNT=$(jq '.changes | length' "$OUTPUT_FILE" 2>/dev/null || echo 'N/A')
      ADD_COUNT=$(jq '.changeCounts.Add // 0' "$OUTPUT_FILE" 2>/dev/null || echo '0')
      EDIT_COUNT=$(jq '.changeCounts.Edit // 0' "$OUTPUT_FILE" 2>/dev/null || echo '0')
      DELETE_COUNT=$(jq '.changeCounts.Delete // 0' "$OUTPUT_FILE" 2>/dev/null || echo '0')
      
      echo ""
      echo "📊 Estadísticas del diff:"
      echo "  - Total de cambios: $CHANGE_COUNT"
      echo "  - Archivos añadidos: $ADD_COUNT"
      echo "  - Archivos editados: $EDIT_COUNT"
      echo "  - Archivos eliminados: $DELETE_COUNT"
      
      echo ""
      echo "📁 Archivos modificados:"
      jq -r '.changes[]?.item?.path // empty' "$OUTPUT_FILE" 2>/dev/null | head -10
      
      # Código de salida exitoso
      exit 0
      
    else
      echo "❌ JSON inválido - mostrando contenido:"
      cat "$OUTPUT_FILE"
      exit 1
    fi
  else
    echo "⚠️  jq no disponible - asumiendo respuesta válida"
    echo "📋 Primeras líneas del archivo:"
    head -5 "$OUTPUT_FILE"
    exit 0
  fi
else
  echo "❌ No se creó el archivo de respuesta"
  exit 1
fi