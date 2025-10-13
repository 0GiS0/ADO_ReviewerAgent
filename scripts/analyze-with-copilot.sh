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
ANALYSIS_PROMPT="Analiza los archivos de este Pull Request y genera un archivo llamado 'pr-comment.md' con formato profesional y elegante.

INSTRUCCIONES DE FORMATO:
- Usa títulos, subtítulos y emojis para resaltar el estado
- Para cada archivo analizado, indica si está correcto o tiene problemas
- Si hay problemas relevantes, incluye un snippet del código problemático con explicación
- Termina con una conclusión general

EJEMPLO DE FORMATO:

---
## 📝 Análisis de Pull Request

### 📄 \`archivo/ruta/ejemplo.json\`

✅ **Estado:** El archivo está bien, no se detectaron problemas relevantes.

### 📄 \`otro/archivo/problematico.cs\`

❌ **Problema detectado:** Falta validación de entrada null

\`\`\`csharp
public void ProcessData(string input)
{
    // ⚠️ PROBLEMA: No se valida si input es null
    var result = input.ToUpper(); // Puede lanzar NullReferenceException
}
\`\`\`

**Recomendación:** Agregar validación de null antes de usar el parámetro.

---

### 📊 Resumen
- Archivos revisados: X
- Problemas encontrados: Y
- Recomendación general: [tu análisis aquí]

IMPORTANTE: Guarda el resultado en un archivo llamado 'pr-comment.md' en el directorio actual."



# Ejecutar Copilot CLI
echo "📡 Llamando a GitHub Copilot CLI para generar el archivo de análisis..."

# Get model from environment or use default
MODEL="${MODEL:-claude-sonnet-4}"
echo "🤖 Using model: $MODEL"

# Ejecutar copilot en modo no interactivo para que genere el archivo
copilot -p "$ANALYSIS_PROMPT" --allow-all-tools --add-dir "$(pwd)" --model "$MODEL"

# Verificar que el archivo fue creado por Copilot
cat "./pr-comment.md"

echo ""
echo "🎉 Análisis completado exitosamente"