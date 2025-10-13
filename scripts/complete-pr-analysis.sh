#!/bin/bash

# Script completo para análisis de PR: obtener diff, descargar archivos y analizarlos con Copilot
# Uso: ./complete-pr-analysis.sh <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> [OUTPUT_DIR]

echo "🚀 Análisis Completo de PR con GitHub Copilot"
echo "============================================="
echo "Obtener diferencias → Descargar archivos → Analizar con Copilot"
echo ""

# Verificar parámetros
if [ $# -lt 4 ] || [ $# -gt 5 ]; then
    echo "❌ ERROR: Número incorrecto de parámetros"
    echo "Uso: $0 <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> [OUTPUT_DIR]"
    echo ""
    echo "Ejemplo:"
    echo "$0 'https://user@dev.azure.com/org/project/_git/repo' 'refs/heads/feature' 'refs/heads/main' 'your-pat' '/path/to/analysis'"
    echo ""
    echo "Este script realiza el flujo completo:"
    echo "  1. 🔍 Obtiene diferencias del PR usando Azure DevOps API"
    echo "  2. 📁 Descarga archivos modificados organizados por rama"
    echo "  3. 🤖 Analiza los cambios con GitHub Copilot CLI"
    echo "  4. 📊 Genera reporte completo de calidad y seguridad"
    exit 1
fi

# Asignar parámetros
SOURCE_REPO_URI="$1"
SOURCE_BRANCH="$2"
TARGET_BRANCH="$3"
PAT="$4"
OUTPUT_DIR="${5:-./pr-analysis-$(date +%Y%m%d_%H%M%S)}"

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📋 Configuración del análisis completo:"
echo "  - Repository URI: $SOURCE_REPO_URI"
echo "  - Source Branch: $SOURCE_BRANCH"
echo "  - Target Branch: $TARGET_BRANCH"
echo "  - Output Directory: $OUTPUT_DIR"
echo ""

# Verificar prerequisitos
echo "🔧 Verificando prerequisitos..."

# Verificar scripts necesarios
REQUIRED_SCRIPTS=("get-and-download-pr-files.sh" "analyze-with-copilot.sh")
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        echo "❌ ERROR: No se encuentra el script $script en $SCRIPT_DIR"
        exit 1
    fi
done

# Verificar GitHub Copilot CLI
if ! command -v copilot &> /dev/null; then
    echo "❌ ERROR: GitHub Copilot CLI no está instalado"
    echo "Instalar desde: https://docs.github.com/en/copilot/github-copilot-in-the-cli"
    exit 1
fi

echo "✅ Todos los prerequisitos verificados"
echo ""

# PASO 1: Obtener diferencias y descargar archivos
echo "🔍 PASO 1: Obteniendo diferencias y descargando archivos"
echo "======================================================="

if ! "$SCRIPT_DIR/get-and-download-pr-files.sh" "$SOURCE_REPO_URI" "$SOURCE_BRANCH" "$TARGET_BRANCH" "$PAT" "$OUTPUT_DIR"; then
    echo "❌ ERROR: Falló la descarga de archivos del PR"
    exit 1
fi

echo ""
echo "✅ Archivos descargados exitosamente en: $OUTPUT_DIR"

# Verificar que se descargaron archivos
if [ ! -d "$OUTPUT_DIR/source" ] || [ -z "$(ls -A "$OUTPUT_DIR/source" 2>/dev/null)" ]; then
    echo "⚠️  No se encontraron archivos fuente para analizar"
    echo "El PR podría estar vacío o contener solo eliminaciones"
    exit 0
fi

# PASO 2: Analizar archivos fuente con Copilot
echo ""
echo "🤖 PASO 2: Analizando archivos con GitHub Copilot CLI"
echo "====================================================="

SOURCE_DIR="$OUTPUT_DIR/source"
COMMENTS_DIR="$OUTPUT_DIR/pr-comments"

if ! "$SCRIPT_DIR/analyze-with-copilot.sh" "$SOURCE_DIR" "$COMMENTS_DIR"; then
    echo "⚠️  El análisis con Copilot tuvo problemas, pero continuando..."
fi

# Verificar que se generaron archivos de comentarios
if [ -d "$COMMENTS_DIR" ] && [ -n "$(ls -A "$COMMENTS_DIR"/*.md 2>/dev/null)" ]; then
    COMMENT_COUNT=$(ls -1 "$COMMENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "✅ Se generaron $COMMENT_COUNT archivos de comentarios en: $COMMENTS_DIR"
else
    echo "⚠️  No se generaron archivos de comentarios"
fi

# PASO 3: Generar análisis comparativo si hay archivos target
echo ""
echo "📊 PASO 3: Generando análisis comparativo"
echo "=========================================="

COMPARISON_FILE="$OUTPUT_DIR/comparison-analysis.md"

if [ -d "$OUTPUT_DIR/target" ] && [ -n "$(ls -A "$OUTPUT_DIR/target" 2>/dev/null)" ]; then
    echo "🔍 Encontrados archivos en target branch, generando comparación..."
    
    cat > "$COMPARISON_FILE" << EOF
# 📊 Análisis Comparativo de Cambios

**Fecha:** $(date)
**Comparación:** Target Branch vs Source Branch

## 🔄 Archivos Modificados

### Archivos en Source Branch (nuevos cambios):
\`\`\`
$(find "$SOURCE_DIR" -type f | sed "s|$SOURCE_DIR/||" | sort)
\`\`\`

### Archivos en Target Branch (versión anterior):
\`\`\`
$(find "$OUTPUT_DIR/target" -type f 2>/dev/null | sed "s|$OUTPUT_DIR/target/||" | sort || echo "Sin archivos en target branch")
\`\`\`

## 📈 Estadísticas de Cambios

- **Archivos añadidos:** $(comm -23 <(find "$SOURCE_DIR" -type f | sed "s|$SOURCE_DIR/||" | sort) <(find "$OUTPUT_DIR/target" -type f 2>/dev/null | sed "s|$OUTPUT_DIR/target/||" | sort || echo "") | wc -l | tr -d ' ')
- **Archivos modificados:** $(comm -12 <(find "$SOURCE_DIR" -type f | sed "s|$SOURCE_DIR/||" | sort) <(find "$OUTPUT_DIR/target" -type f 2>/dev/null | sed "s|$OUTPUT_DIR/target/||" | sort || echo "") | wc -l | tr -d ' ')
- **Total de cambios:** $(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')

## 🔍 Diferencias Detalladas

EOF

    # Generar diff para archivos comunes
    while IFS= read -r file; do
        if [ -f "$OUTPUT_DIR/target/$file" ] && [ -f "$SOURCE_DIR/$file" ]; then
            echo "### 📄 $file" >> "$COMPARISON_FILE"
            echo "" >> "$COMPARISON_FILE"
            echo "\`\`\`diff" >> "$COMPARISON_FILE"
            diff -u "$OUTPUT_DIR/target/$file" "$SOURCE_DIR/$file" 2>/dev/null || echo "Error al generar diff para $file" >> "$COMPARISON_FILE"
            echo "\`\`\`" >> "$COMPARISON_FILE"
            echo "" >> "$COMPARISON_FILE"
        fi
    done < <(find "$SOURCE_DIR" -type f | sed "s|$SOURCE_DIR/||")
    
    echo "✅ Análisis comparativo generado: $COMPARISON_FILE"
else
    echo "ℹ️  Solo hay archivos nuevos (no hay target branch para comparar)"
fi

# PASO 4: Generar reporte ejecutivo
echo ""
echo "📋 PASO 4: Generando reporte ejecutivo"
echo "======================================"

EXECUTIVE_REPORT="$OUTPUT_DIR/executive-summary.md"

cat > "$EXECUTIVE_REPORT" << EOF
# 📋 Reporte Ejecutivo - Análisis de Pull Request

**Fecha de análisis:** $(date)
**Herramientas utilizadas:** Azure DevOps API + GitHub Copilot CLI

## 📊 Información del Pull Request

$(cat "$OUTPUT_DIR/metadata/pr-info.json" | jq -r '
"- **Organización:** " + .repository.organization + 
"\n- **Proyecto:** " + .repository.project +
"\n- **Repositorio:** " + .repository.repository +
"\n- **Rama fuente:** " + .branches.source +
"\n- **Rama destino:** " + .branches.target +
"\n- **Total de archivos modificados:** " + (.statistics.total_files | tostring) +
"\n- **Descargas exitosas:** " + (.statistics.successful_downloads | tostring)
')

## 📁 Estructura de Archivos Analizados

\`\`\`
$(find "$OUTPUT_DIR" -name "*.md" -o -name "*.json" | sed "s|$OUTPUT_DIR/||" | sort)
\`\`\`

## 🔗 Archivos del Análisis

1. **[Análisis de Copilot](./copilot-analysis.md)** - Análisis detallado de calidad y seguridad
2. **[Análisis Comparativo](./comparison-analysis.md)** - Diferencias entre versiones $([ -f "$COMPARISON_FILE" ] && echo "(disponible)" || echo "(no disponible - solo archivos nuevos)")
3. **[Metadatos del PR](./metadata/pr-info.json)** - Información técnica del Pull Request
4. **[Diff Original](./metadata/original-diff.json)** - Diferencias completas de Azure DevOps

## 🎯 Próximos Pasos Recomendados

1. **Revisar análisis de Copilot** para identificar problemas de calidad y seguridad
2. **Validar cambios críticos** identificados en el análisis
3. **Implementar mejoras sugeridas** antes de aprobar el PR
4. **Ejecutar pruebas adicionales** si se identificaron vulnerabilidades de seguridad

## 📞 Información de Contacto

- **Generado por:** ReviewerAgent v1.0
- **Directorio de análisis:** \`$OUTPUT_DIR\`
- **Comando utilizado:** \`$(basename "$0") $*\`

---

*Para regenerar este análisis, ejecuta el mismo comando desde el directorio del proyecto.*
EOF

echo "✅ Reporte ejecutivo generado: $EXECUTIVE_REPORT"

# Resumen final
echo ""
echo "🎉 ANÁLISIS COMPLETO FINALIZADO"
echo "==============================="
echo ""
echo "📁 Todos los archivos generados en: $OUTPUT_DIR"
echo ""
echo "📄 Archivos principales:"
echo "  ├── 📊 executive-summary.md      # Reporte ejecutivo principal"
echo "  ├── 🤖 copilot-analysis.md       # Análisis detallado con Copilot"
echo "  ├── 📈 comparison-analysis.md     # Comparación de cambios $([ -f "$COMPARISON_FILE" ] && echo "(disponible)" || echo "(no disponible)")"
echo "  ├── 📁 source/                   # Archivos de la rama fuente"
echo "  ├── 📁 target/                   # Archivos de la rama destino"
echo "  └── 📁 metadata/                 # Información técnica del PR"
echo ""
echo "🔧 Comandos útiles:"
echo "  # Ver reporte principal:"
echo "  cat '$EXECUTIVE_REPORT'"
echo ""
echo "  # Abrir análisis de Copilot:"
echo "  code '$ANALYSIS_FILE'"
echo ""
echo "  # Ver estadísticas del PR:"
echo "  cat '$OUTPUT_DIR/metadata/pr-info.json' | jq '.statistics'"
echo ""

# Ofrecer abrir el reporte ejecutivo
read -p "¿Abrir el reporte ejecutivo? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v code &> /dev/null; then
        echo "📝 Abriendo reporte ejecutivo en VS Code..."
        code "$EXECUTIVE_REPORT"
    else
        echo "📝 Mostrando reporte ejecutivo:"
        cat "$EXECUTIVE_REPORT"
    fi
fi

echo ""
echo "✅ Análisis completo disponible en: $OUTPUT_DIR"