#!/bin/bash
set -e

echo "📋 Getting changed files in PR..."

# Obtener la rama base y la rama de la PR desde variables de entorno de Azure DevOps
TARGET_BRANCH="${SYSTEM_PULLREQUEST_TARGETBRANCH}"
SOURCE_BRANCH="${SYSTEM_PULLREQUEST_SOURCEBRANCH}"

# Validar que las variables existen
if [ -z "$TARGET_BRANCH" ] || [ -z "$SOURCE_BRANCH" ]; then
    echo "❌ Error: Variables de rama no configuradas"
    echo "TARGET_BRANCH: $TARGET_BRANCH"
    echo "SOURCE_BRANCH: $SOURCE_BRANCH"
    exit 1
fi

# Limpiar nombres de rama (remover refs/heads/)
TARGET_BRANCH=${TARGET_BRANCH#refs/heads/}
SOURCE_BRANCH=${SOURCE_BRANCH#refs/heads/}

echo "Rama objetivo: $TARGET_BRANCH"
echo "Rama origen: $SOURCE_BRANCH"

# Obtener los archivos modificados
git diff --name-only origin/$TARGET_BRANCH...HEAD > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"

echo ""
echo "Archivos modificados:"
cat "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"

FILE_COUNT=$(wc -l < "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt")
echo ""
echo "✅ $FILE_COUNT archivos modificados detectados"
