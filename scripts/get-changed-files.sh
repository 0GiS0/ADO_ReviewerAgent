#!/bin/bash
set -e

echo "📋 Getting changed files in PR..."

# Obtener información de la PR desde variables de entorno de Azure DevOps
TARGET_BRANCH="${SYSTEM_PULLREQUEST_TARGETBRANCH}"
SOURCE_BRANCH="${SYSTEM_PULLREQUEST_SOURCEBRANCH}"
SOURCE_COMMIT_ID="${SYSTEM_PULLREQUEST_SOURCECOMMITID}"
TARGET_COMMIT_ID="${SYSTEM_PULLREQUEST_TARGETCOMMITID}"

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
if [ -n "$SOURCE_COMMIT_ID" ]; then
    echo "Source Commit: $SOURCE_COMMIT_ID"
fi
if [ -n "$TARGET_COMMIT_ID" ]; then
    echo "Target Commit: $TARGET_COMMIT_ID"
fi

# En Azure DevOps PR pipelines:
# - HEAD es el merge commit temporal
# - HEAD^1 es el commit del target branch
# - HEAD^2 es el último commit del source branch (si el source es del mismo repo)
echo ""
echo "🔍 Git status:"
echo "Current commit (HEAD): $(git rev-parse HEAD)"
echo "Current branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'detached')"

# Obtener los archivos modificados
echo ""
echo "📝 Getting changed files..."

# Estrategia 1: Si tenemos los commit IDs específicos, usarlos directamente
# Esto funciona incluso si el source branch es de otro repositorio/fork
if [ -n "$TARGET_COMMIT_ID" ] && [ -n "$SOURCE_COMMIT_ID" ]; then
    echo "Using specific commit IDs from PR variables"
    if git diff --name-only "$TARGET_COMMIT_ID" "$SOURCE_COMMIT_ID" > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt" 2>/dev/null; then
        echo "✅ Method: Commit IDs diff"
    else
        echo "⚠️ Commit IDs not available locally, using merge commit method"
        git diff --name-only HEAD^1 HEAD > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt" 2>/dev/null || \
        git diff-tree --no-commit-id --name-only -r HEAD > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"
        echo "✅ Method: Merge commit parents"
    fi
# Estrategia 2: Usar los padres del merge commit (HEAD^1 es target, HEAD es el merge)
# Este es el método más confiable para PRs en Azure DevOps
elif git rev-parse HEAD^1 > /dev/null 2>&1; then
    echo "Using merge commit parents (HEAD^1..HEAD)"
    git diff --name-only HEAD^1 HEAD > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"
    echo "✅ Method: HEAD^1..HEAD"
# Estrategia 3: Último commit (fallback para casos raros)
else
    echo "⚠️ Using last commit as fallback"
    git diff-tree --no-commit-id --name-only -r HEAD > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"
    echo "✅ Method: Last commit files"
fi

echo ""
echo "Archivos modificados:"
cat "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"

FILE_COUNT=$(wc -l < "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt" | tr -d ' ')
echo ""
echo "✅ $FILE_COUNT archivos modificados detectados"
