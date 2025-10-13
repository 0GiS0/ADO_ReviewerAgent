#!/bin/bash

# Script para descargar archivos modificados de un PR usando Azure DevOps API
# Uso: ./download-pr-files.sh <DIFF_JSON_FILE> <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> [OUTPUT_DIR]

echo "📁 Descarga de archivos modificados del PR"
echo "=========================================="

# Verificar parámetros
if [ $# -lt 5 ] || [ $# -gt 6 ]; then
    echo "❌ ERROR: Número incorrecto de parámetros"
    echo "Uso: $0 <DIFF_JSON_FILE> <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> [OUTPUT_DIR]"
    echo ""
    echo "Ejemplo:"
    echo "$0 '/path/to/diff.json' 'https://user@dev.azure.com/org/project/_git/repo' 'refs/heads/feature' 'refs/heads/main' 'your-pat' '/path/to/output'"
    exit 1
fi

# Asignar parámetros
DIFF_JSON_FILE="$1"
SOURCE_REPO_URI="$2"
SOURCE_BRANCH="$3"
TARGET_BRANCH="$4"
PAT="$5"
OUTPUT_DIR="${6:-./pr-files-$(date +%Y%m%d_%H%M%S)}"

echo "📋 Configuración:"
echo "  - Archivo diff JSON: $DIFF_JSON_FILE"
echo "  - Repository URI: $SOURCE_REPO_URI"
echo "  - Source Branch: $SOURCE_BRANCH"
echo "  - Target Branch: $TARGET_BRANCH"
echo "  - Output Directory: $OUTPUT_DIR"
echo ""

# Verificar que existe el archivo JSON
if [ ! -f "$DIFF_JSON_FILE" ]; then
    echo "❌ ERROR: No se encuentra el archivo $DIFF_JSON_FILE"
    exit 1
fi

# Verificar que jq está disponible
if ! command -v jq &> /dev/null; then
    echo "❌ ERROR: jq es requerido para procesar el JSON"
    echo "Instalar con: brew install jq (macOS) o apt-get install jq (Ubuntu)"
    exit 1
fi

# Verificar que el JSON es válido
if ! jq empty "$DIFF_JSON_FILE" 2>/dev/null; then
    echo "❌ ERROR: JSON inválido en $DIFF_JSON_FILE"
    exit 1
fi

# Extraer información del repositorio
echo "🔍 Procesando URI del repositorio..."
TEMP_URI=$(echo $SOURCE_REPO_URI | sed 's|https://[^@]*@||')

# Obtener información del repo
ORG=$(echo $TEMP_URI | awk -F'/' '{print $2}')
PROJECT=$(echo $TEMP_URI | awk -F'/' '{print $3}' | sed 's/%20/ /g')
REPO=$(echo $TEMP_URI | awk -F'/' '{print $5}')
PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/ /%20/g')

# Limpiar prefijos refs/heads/ si existen
SOURCE_BRANCH_CLEAN=$(echo "$SOURCE_BRANCH" | sed 's|refs/heads/||')
TARGET_BRANCH_CLEAN=$(echo "$TARGET_BRANCH" | sed 's|refs/heads/||')

echo "  - ORGANIZATION: $ORG"
echo "  - PROJECT: $PROJECT"
echo "  - REPOSITORY: $REPO"
echo "  - SOURCE BRANCH: $SOURCE_BRANCH_CLEAN"
echo "  - TARGET BRANCH: $TARGET_BRANCH_CLEAN"
echo ""

# Crear directorios de salida
echo "📁 Creando estructura de directorios..."
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/source"
mkdir -p "$OUTPUT_DIR/target" 
mkdir -p "$OUTPUT_DIR/metadata"

# Generar header de autenticación
AUTH_HEADER=$(printf "%s:" "$PAT" | base64 -w 0)

# Obtener lista de archivos modificados
echo "📋 Obteniendo lista de archivos modificados..."
MODIFIED_FILES=$(jq -r '.changes[]? | select(.item.gitObjectType == "blob") | .item.path' "$DIFF_JSON_FILE")

if [ -z "$MODIFIED_FILES" ]; then
    echo "⚠️  No se encontraron archivos modificados en el diff"
    exit 0
fi

FILE_COUNT=$(echo "$MODIFIED_FILES" | wc -l | tr -d ' ')
echo "✅ Encontrados $FILE_COUNT archivos para descargar"
echo ""

# Función para descargar un archivo de una rama específica
download_file() {
    local file_path="$1"
    local branch="$2"
    local output_subdir="$3"
    local display_name="$4"
    
    echo "📥 Descargando: $file_path ($display_name)"
    
    # Crear directorio para el archivo
    local file_dir="$OUTPUT_DIR/$output_subdir/$(dirname "$file_path")"
    mkdir -p "$file_dir"
    
    # URL de la API para obtener el contenido del archivo
    local api_url="https://dev.azure.com/$ORG/$PROJECT_ENCODED/_apis/git/repositories/$REPO/items"
    local params="path=$file_path&version=$branch&versionType=branch&includeContent=true&api-version=7.2-preview.1"
    local full_url="$api_url?$params"
    
    # Archivo de destino
    local output_file="$OUTPUT_DIR/$output_subdir/$file_path"
    
    # Descargar el archivo
    curl -s \
        -H "Authorization: Basic $AUTH_HEADER" \
        -H "Accept: application/json" \
        "$full_url" \
        -o "$output_file.tmp" \
        2>/dev/null
    
    local curl_exit_code=$?
    
    if [ $curl_exit_code -eq 0 ]; then
        # Verificar si la respuesta es un error de API (JSON con mensaje de error)
        if jq -e '.message' "$output_file.tmp" >/dev/null 2>&1; then
            local error_msg=$(jq -r '.message' "$output_file.tmp" 2>/dev/null)
            echo "  ❌ Error de API: $error_msg"
            rm -f "$output_file.tmp"
            return 1
        else
            # Verificar si el JSON contiene contenido
            if jq -e '.content' "$output_file.tmp" >/dev/null 2>&1; then
                # Extraer el contenido del JSON y decodificar base64
                jq -r '.content' "$output_file.tmp" | base64 -d > "$output_file" 2>/dev/null
                if [ $? -eq 0 ] && [ -s "$output_file" ]; then
                    local file_size=$(du -h "$output_file" | cut -f1)
                    echo "  ✅ Descargado ($file_size)"
                    rm -f "$output_file.tmp"
                    return 0
                else
                    # Si falla base64, guardar contenido como texto plano
                    jq -r '.content // empty' "$output_file.tmp" > "$output_file"
                    local file_size=$(du -h "$output_file" | cut -f1)
                    echo "  ✅ Descargado como texto ($file_size)"
                    rm -f "$output_file.tmp"
                    return 0
                fi
            else
                # Si no hay campo content, guardar la respuesta completa
                mv "$output_file.tmp" "$output_file"
                local file_size=$(du -h "$output_file" | cut -f1)
                echo "  ⚠️  Descargado (metadatos) ($file_size)"
                return 0
            fi
        fi
    else
        echo "  ❌ Error en descarga (curl code: $curl_exit_code)"
        rm -f "$output_file.tmp"
        return 1
    fi
}

# Contadores
SUCCESSFUL_DOWNLOADS=0
FAILED_DOWNLOADS=0

# Procesar cada archivo modificado
echo "🔄 Procesando archivos..."
while IFS= read -r file_path; do
    if [ -n "$file_path" ]; then
        echo ""
        echo "📄 Procesando: $file_path"
        
        # Descargar versión de la rama fuente
        if download_file "$file_path" "$SOURCE_BRANCH_CLEAN" "source" "source branch"; then
            ((SUCCESSFUL_DOWNLOADS++))
        else
            ((FAILED_DOWNLOADS++))
        fi
        
        # Descargar versión de la rama destino (puede fallar si es archivo nuevo)
        if download_file "$file_path" "$TARGET_BRANCH_CLEAN" "target" "target branch"; then
            ((SUCCESSFUL_DOWNLOADS++))
        else
            echo "  ⚠️  No se pudo descargar de target branch (posiblemente archivo nuevo)"
        fi
    fi
done <<< "$MODIFIED_FILES"

# Crear archivo de metadatos
echo ""
echo "📝 Generando metadatos..."
METADATA_FILE="$OUTPUT_DIR/metadata/pr-info.json"

cat > "$METADATA_FILE" << EOF
{
  "download_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "repository": {
    "organization": "$ORG",
    "project": "$PROJECT",
    "repository": "$REPO",
    "uri": "$SOURCE_REPO_URI"
  },
  "branches": {
    "source": "$SOURCE_BRANCH_CLEAN",
    "target": "$TARGET_BRANCH_CLEAN"
  },
  "statistics": {
    "total_files": $FILE_COUNT,
    "successful_downloads": $SUCCESSFUL_DOWNLOADS,
    "failed_downloads": $FAILED_DOWNLOADS
  },
  "diff_file": "$DIFF_JSON_FILE"
}
EOF

# Copiar el archivo diff original a metadata
cp "$DIFF_JSON_FILE" "$OUTPUT_DIR/metadata/original-diff.json"

echo ""
echo "📊 Resumen de descarga:"
echo "  - Total archivos: $FILE_COUNT"
echo "  - Descargas exitosas: $SUCCESSFUL_DOWNLOADS"
echo "  - Descargas fallidas: $FAILED_DOWNLOADS"
echo "  - Directorio de salida: $OUTPUT_DIR"
echo ""
echo "📁 Estructura creada:"
echo "  $OUTPUT_DIR/"
echo "  ├── source/         # Archivos de la rama fuente"
echo "  ├── target/         # Archivos de la rama destino"  
echo "  └── metadata/       # Información del PR y diff original"
echo "      ├── pr-info.json"
echo "      └── original-diff.json"
echo ""

if [ $FAILED_DOWNLOADS -gt 0 ]; then
    echo "⚠️  Algunas descargas fallaron. Revisar logs arriba para detalles."
    exit 1
else
    echo "✅ Todos los archivos descargados exitosamente"
    exit 0
fi