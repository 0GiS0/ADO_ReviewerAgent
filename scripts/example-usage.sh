#!/bin/bash

# Script de ejemplo para demostrar el uso de los scripts de descarga de PR
# Este es un ejemplo completo de cómo usar los scripts para analizar un PR

echo "📚 Ejemplo de uso - Descarga y análisis de archivos de PR"
echo "======================================================="
echo ""
echo "Este script es un ejemplo de cómo usar los scripts de descarga"
echo "para obtener y analizar archivos modificados en un Pull Request."
echo ""

# Configuración de ejemplo (VALORES REALES PARA TESTING)
EXAMPLE_REPO_URI="https://returngisorg@dev.azure.com/returngisorg/GitHub%20Copilot%20CLI/_git/Demo"
EXAMPLE_SOURCE_BRANCH="refs/heads/copilot/465"
EXAMPLE_TARGET_BRANCH="refs/heads/main"
EXAMPLE_PAT="4U7lrCeDGknOSOhsLPmZmkRqvwCfYA3A5twU2kAHQk9aX8oMVx4XJQQJ99BJACAAAAApTnvlAAASAZDO24He"
EXAMPLE_OUTPUT_DIR="./test-pr-analysis"

echo "🔧 Configuración de ejemplo:"
echo "  - Repository: $EXAMPLE_REPO_URI"
echo "  - Source Branch: $EXAMPLE_SOURCE_BRANCH"
echo "  - Target Branch: $EXAMPLE_TARGET_BRANCH"
echo "  - PAT: [HIDDEN FOR SECURITY]"
echo "  - Output Directory: $EXAMPLE_OUTPUT_DIR"
echo ""

echo "⚠️  IMPORTANTE: Este es solo un ejemplo."
echo "   Reemplaza los valores arriba con tu información real antes de ejecutar."
echo ""

read -p "¿Continuar con el ejemplo? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "👋 Ejemplo cancelado."
    exit 0
fi

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "🚀 Ejecutando proceso completo..."
echo ""

# Verificar que existen los scripts
if [ ! -f "$SCRIPT_DIR/get-and-download-pr-files.sh" ]; then
    echo "❌ ERROR: No se encuentra get-and-download-pr-files.sh"
    exit 1
fi

# Ejecutar el script completo
if "$SCRIPT_DIR/get-and-download-pr-files.sh" \
    "$EXAMPLE_REPO_URI" \
    "$EXAMPLE_SOURCE_BRANCH" \
    "$EXAMPLE_TARGET_BRANCH" \
    "$EXAMPLE_PAT" \
    "$EXAMPLE_OUTPUT_DIR"; then
    
    echo ""
    echo "🎉 Proceso completado exitosamente!"
    echo ""
    echo "📊 Análisis de los resultados:"
    
    # Mostrar estadísticas si jq está disponible
    if command -v jq &> /dev/null && [ -f "$EXAMPLE_OUTPUT_DIR/metadata/pr-info.json" ]; then
        echo ""
        echo "📈 Estadísticas del PR:"
        jq -r '
        "  - Total de archivos modificados: " + (.statistics.total_files | tostring) +
        "\n  - Descargas exitosas: " + (.statistics.successful_downloads | tostring) +
        "\n  - Descargas fallidas: " + (.statistics.failed_downloads | tostring) +
        "\n  - Rama fuente: " + .branches.source +
        "\n  - Rama destino: " + .branches.target
        ' "$EXAMPLE_OUTPUT_DIR/metadata/pr-info.json"
    fi
    
    # Mostrar algunos archivos descargados
    echo ""
    echo "📁 Archivos descargados (primeros 5):"
    if [ -d "$EXAMPLE_OUTPUT_DIR/source" ]; then
        find "$EXAMPLE_OUTPUT_DIR/source" -type f | head -5 | while read -r file; do
            relative_path=${file#$EXAMPLE_OUTPUT_DIR/source/}
            echo "  ✅ $relative_path"
        done
    fi
    
    echo ""
    echo "💡 Próximos pasos sugeridos:"
    echo "  1. Revisar archivos en: $EXAMPLE_OUTPUT_DIR"
    echo "  2. Comparar cambios entre source/ y target/"
    echo "  3. Usar herramientas de diff para análisis detallado:"
    echo "     diff -r $EXAMPLE_OUTPUT_DIR/target $EXAMPLE_OUTPUT_DIR/source"
    echo ""
    echo "  4. Integrar con herramientas de análisis de código:"
    echo "     # Ejemplo con GitHub Copilot CLI"
    echo "     gh copilot suggest 'Analiza estos cambios de código'"
    
else
    echo ""
    echo "❌ El proceso falló. Revisar logs arriba para más detalles."
    echo ""
    echo "🔍 Posibles causas:"
    echo "  - PAT inválido o sin permisos"
    echo "  - URI del repositorio incorrecto"
    echo "  - Ramas que no existen"
    echo "  - Problemas de conectividad"
fi

echo ""
echo "📝 Para personalizar este ejemplo:"
echo "  1. Edita las variables al inicio del script"
echo "  2. Reemplaza con tu información real de Azure DevOps"
echo "  3. Ejecuta: ./scripts/example-usage.sh"