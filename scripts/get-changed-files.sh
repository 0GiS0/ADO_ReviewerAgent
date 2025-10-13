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

# En Azure DevOps, el pipeline hace checkout del merge commit de la PR
# System.PullRequest.SourceCommitId y TargetCommitId contienen los commits específicos
echo ""
echo "� Git status:"
echo "Current commit: $(git rev-parse HEAD)"
echo "Current branch: $(git rev-parse --abbrev-ref HEAD)"

# Listar todas las ramas disponibles
echo ""
echo "Available branches:"
git branch -a | head -20

# Actualizar referencias remotas
echo ""
echo "📡 Fetching branches..."
git fetch origin "$TARGET_BRANCH" --depth=50 2>&1 || echo "Could not fetch $TARGET_BRANCH"
git fetch origin "$SOURCE_BRANCH" --depth=50 2>&1 || echo "Could not fetch $SOURCE_BRANCH"

# Obtener los archivos modificados - probar múltiples métodos
echo ""
echo "📝 Getting changed files..."

# Azure DevOps hace merge de la PR, así que HEAD^ suele ser el target branch
# y HEAD contiene los cambios de la PR

# Método 1: Comparar HEAD con merge-base
if git merge-base "origin/$TARGET_BRANCH" HEAD > /dev/null 2>&1; then
    MERGE_BASE=$(git merge-base "origin/$TARGET_BRANCH" HEAD)
    echo "Merge base found: $MERGE_BASE"
    git diff --name-only "$MERGE_BASE" HEAD > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"
    echo "✅ Using merge-base method"
# Método 2: Comparar con origin/TARGET_BRANCH directamente  
elif git rev-parse "origin/$TARGET_BRANCH" > /dev/null 2>&1; then
    git diff --name-only "origin/$TARGET_BRANCH"...HEAD > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt" 2>/dev/null
    echo "✅ Using three-dot diff"
# Método 3: Usar el padre del merge commit (HEAD^)
elif [ "$(git rev-parse HEAD^1 2>/dev/null)" ]; then
    git diff --name-only HEAD^1 HEAD > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"
    echo "✅ Using HEAD^1 (PR merge commit parent)"
# Método 4: Último commit
else
    git diff-tree --no-commit-id --name-only -r HEAD > "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"
    echo "⚠️ Fallback: Using last commit files"
fi

echo ""
echo "Archivos modificados:"
cat "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt"

FILE_COUNT=$(wc -l < "$BUILD_ARTIFACTSTAGINGDIRECTORY/changed_files.txt")
echo ""
echo "✅ $FILE_COUNT archivos modificados detectados"
