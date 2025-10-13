#!/bin/bash

# Script wrapper para obtener diferencias de PR y descargar archivos modificados
# Uso: ./get-and-download-pr-files.sh <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> [OUTPUT_DIR]

echo "🚀 Obtener y descargar archivos modificados del PR"
echo "==============================================="

# Verificar parámetros
if [ $# -lt 4 ] || [ $# -gt 5 ]; then
    echo "❌ ERROR: Número incorrecto de parámetros"
    echo "Uso: $0 <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> [OUTPUT_DIR]"
    echo ""
    echo "Ejemplo:"
    echo "$0 'https://user@dev.azure.com/org/project/_git/repo' 'refs/heads/feature' 'refs/heads/main' 'your-pat' '/path/to/output'"
    echo ""
    echo "Descripción de parámetros:"
    echo "  SOURCE_REPO_URI: URI completa del repositorio en Azure DevOps"
    echo "  SOURCE_BRANCH:   Rama fuente del PR (ej: refs/heads/feature-branch)"
    echo "  TARGET_BRANCH:   Rama destino del PR (ej: refs/heads/main)"
    echo "  PAT:            Personal Access Token para autenticación"
    echo "  OUTPUT_DIR:     [Opcional] Directorio de salida (por defecto: ./pr-files-TIMESTAMP)"
    exit 1
fi

# Asignar parámetros
SOURCE_REPO_URI="$1"
SOURCE_BRANCH="$2"
TARGET_BRANCH="$3"
PAT="$4"
OUTPUT_DIR="${5:-./pr-files-$(date +%Y%m%d_%H%M%S)}"

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Archivos temporales
TEMP_DIFF_FILE="/tmp/pr-diff-$(date +%s).json"

echo "📋 Configuración:"
echo "  - Repository URI: $SOURCE_REPO_URI"
echo "  - Source Branch: $SOURCE_BRANCH"
echo "  - Target Branch: $TARGET_BRANCH"
echo "  - Output Directory: $OUTPUT_DIR"
echo "  - Temp Diff File: $TEMP_DIFF_FILE"
echo ""

# Verificar que existen los scripts necesarios
if [ ! -f "$SCRIPT_DIR/get-pr-diff.sh" ]; then
    echo "❌ ERROR: No se encuentra get-pr-diff.sh en $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/download-pr-files.sh" ]; then
    echo "❌ ERROR: No se encuentra download-pr-files.sh en $SCRIPT_DIR"
    exit 1
fi

# Paso 1: Obtener diferencias del PR
echo "🔍 PASO 1: Obteniendo diferencias del PR..."
echo "============================================"

if ! "$SCRIPT_DIR/get-pr-diff.sh" "$SOURCE_REPO_URI" "$SOURCE_BRANCH" "$TARGET_BRANCH" "$PAT" "$TEMP_DIFF_FILE"; then
    echo "❌ ERROR: Falló la obtención del diff del PR"
    exit 1
fi

# Verificar que se creó el archivo diff y tiene contenido válido
if [ ! -f "$TEMP_DIFF_FILE" ] || [ ! -s "$TEMP_DIFF_FILE" ]; then
    echo "❌ ERROR: No se generó el archivo diff o está vacío"
    exit 1
fi

echo ""
echo "✅ Diff obtenido exitosamente"

# Paso 2: Descargar archivos modificados
echo ""
echo "📁 PASO 2: Descargando archivos modificados..."
echo "============================================"

if ! "$SCRIPT_DIR/download-pr-files.sh" "$TEMP_DIFF_FILE" "$SOURCE_REPO_URI" "$SOURCE_BRANCH" "$TARGET_BRANCH" "$PAT" "$OUTPUT_DIR"; then
    echo "❌ ERROR: Falló la descarga de archivos"
    # No eliminar archivo temporal para debug
    echo "🔍 Archivo diff guardado para debug en: $TEMP_DIFF_FILE"
    exit 1
fi

echo ""
echo "✅ Descarga completada exitosamente"

# Limpiar archivo temporal
rm -f "$TEMP_DIFF_FILE"

echo ""
echo "🎉 PROCESO COMPLETADO"
echo "==================="
echo "📁 Todos los archivos se han descargado en: $OUTPUT_DIR"
echo ""
echo "💡 Estructura de archivos creada:"
echo "  $OUTPUT_DIR/"
echo "  ├── source/           # Archivos de la rama fuente ($SOURCE_BRANCH)"
echo "  ├── target/           # Archivos de la rama destino ($TARGET_BRANCH)"
echo "  └── metadata/"
echo "      ├── pr-info.json  # Información del PR y estadísticas"
echo "      └── original-diff.json # Diff completo en formato JSON"
echo ""
echo "🔧 Comandos útiles:"
echo "  # Ver estadísticas del PR:"
echo "  cat '$OUTPUT_DIR/metadata/pr-info.json' | jq '.statistics'"
echo ""
echo "  # Listar archivos modificados:"
echo "  find '$OUTPUT_DIR/source' -type f | head -10"
echo ""
echo "  # Comparar un archivo específico:"
echo "  diff '$OUTPUT_DIR/target/path/to/file' '$OUTPUT_DIR/source/path/to/file'"