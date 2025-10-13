#!/bin/bash

# Script para analizar archivos descargados de un PR usando GitHub Copilot CLI
# Uso: ./analyze-with-copilot.sh [PR_DIRECTORY] [OUTPUT_FILE]

echo "🤖 Análisis de PR con GitHub Copilot CLI"
echo "======================================="

# Parámetros
PR_DIRECTORY="${1:-.}"
OUTPUT_FILE="${2:-./copilot-analysis-$(date +%Y%m%d_%H%M%S).md}"

echo "📋 Configuración del análisis:"
echo "  - Directorio del PR: $PR_DIRECTORY"
echo "  - Archivo de salida: $OUTPUT_FILE"
echo ""

# Verificar que el directorio existe
if [ ! -d "$PR_DIRECTORY" ]; then
    echo "❌ ERROR: El directorio $PR_DIRECTORY no existe"
    exit 1
fi

# Verificar que GitHub Copilot CLI está instalado
if ! command -v copilot &> /dev/null; then
    echo "❌ ERROR: GitHub Copilot CLI (copilot) no está instalado"
    echo "Instalar desde: https://docs.github.com/en/copilot/github-copilot-in-the-cli"
    exit 1
fi

# Cambiar al directorio del PR
cd "$PR_DIRECTORY" || {
    echo "❌ ERROR: No se puede acceder al directorio $PR_DIRECTORY"
    exit 1
}

echo "📁 Analizando directorio: $(pwd)"
echo ""

# Verificar que hay archivos para analizar
TOTAL_FILES=$(find . -type f -name "*.cs" -o -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.java" -o -name "*.cpp" -o -name "*.c" -o -name "*.php" -o -name "*.rb" -o -name "*.go" -o -name "*.rs" -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" -o -name "*.xml" -o -name "*.html" -o -name "*.css" -o -name "*.scss" -o -name "*.sql" -o -name "*.sh" -o -name "*.ps1" -o -name "*.dockerfile" -o -name "Dockerfile*" 2>/dev/null | wc -l | tr -d ' ')

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "⚠️  No se encontraron archivos de código para analizar"
    echo "🔍 Archivos disponibles:"
    find . -type f | head -10
    echo ""
    read -p "¿Continuar con el análisis de todos los archivos? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "👋 Análisis cancelado."
        exit 0
    fi
fi

echo "📊 Encontrados archivos para analizar: $TOTAL_FILES"
echo ""

# Crear el prompt para Copilot
ANALYSIS_PROMPT="Analiza todos los archivos en este directorio y genera un archivo markdown llamado pr-comment.md con un resumen muy breve para revisión de Pull Request:
- Si hay problemas de severidad ALTA o MEDIA, enuméralos brevemente (máximo 1 línea por problema, solo descripción y severidad).
- Si no hay problemas de severidad alta o media, escribe simplemente: '✅ El archivo está bien, no se detectaron problemas relevantes.'
- No incluyas problemas de severidad baja ni recomendaciones menores.
- No incluyas puntuaciones, ni veredictos extensos, ni secciones adicionales.
- El archivo debe ser lo más corto y directo posible, solo lo esencial para el revisor.
- Siempre se tiene que mencionar el nombre del archivo analizado.
- Si hay alguna mejora relacionada se debe incluir un snippet del código que no está bien."



# Ejecutar Copilot CLI
echo "📡 Llamando a GitHub Copilot CLI para generar el archivo de análisis..."

# Ejecutar copilot en modo no interactivo para que genere el archivo
copilot -p "$ANALYSIS_PROMPT" --allow-all-tools --add-dir "$(pwd)"

# Verificar que el archivo fue creado por Copilot
cat "./pr-comment.md"

echo ""
echo "🎉 Análisis completado exitosamente"