#!/bin/bash
set -e

echo "📋 Getting changed files in PR..."

# Obtener la rama base y la rama de la PR
TARGET_BRANCH=$(System.PullRequest.TargetBranch)
SOURCE_BRANCH=$(System.PullRequest.SourceBranch)

# Limpiar nombres de rama (remover refs/heads/)
TARGET_BRANCH=${TARGET_BRANCH#refs/heads/}
SOURCE_BRANCH=${SOURCE_BRANCH#refs/heads/}

echo "Rama objetivo: $TARGET_BRANCH"
echo "Rama origen: $SOURCE_BRANCH"

# Obtener los archivos modificados
git diff --name-only origin/$TARGET_BRANCH...HEAD > $(Build.ArtifactStagingDirectory)/changed_files.txt

echo ""
echo "Archivos modificados:"
cat $(Build.ArtifactStagingDirectory)/changed_files.txt

FILE_COUNT=$(wc -l < $(Build.ArtifactStagingDirectory)/changed_files.txt)
echo ""
echo "✅ $FILE_COUNT archivos modificados detectados"
