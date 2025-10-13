#!/bin/bash
set -e

echo "🔍 Analyzing PR changes with Copilot..."

# Verificar que Copilot CLI esté instalado
if ! command -v copilot &> /dev/null; then
    echo "❌ Error: copilot CLI no está instalado"
    exit 1
fi

# Obtener información de la PR desde variables de entorno
TARGET_BRANCH="${SYSTEM_PULLREQUEST_TARGETBRANCH#refs/heads/}"
SOURCE_BRANCH="${SYSTEM_PULLREQUEST_SOURCEBRANCH#refs/heads/}"
PR_ID="$SYSTEM_PULLREQUEST_PULLREQUESTID"
SOURCE_COMMIT_ID="${SYSTEM_PULLREQUEST_SOURCECOMMITID}"
TARGET_COMMIT_ID="${SYSTEM_PULLREQUEST_TARGETCOMMITID}"

# Validar que las variables existen
if [ -z "$TARGET_BRANCH" ] || [ -z "$SOURCE_BRANCH" ] || [ -z "$PR_ID" ]; then
    echo "❌ Error: Variables de PR no configuradas"
    echo "TARGET_BRANCH: $TARGET_BRANCH"
    echo "SOURCE_BRANCH: $SOURCE_BRANCH"
    echo "PR_ID: $PR_ID"
    exit 1
fi

echo "📋 PR Information:"
echo "  - PR #$PR_ID"
echo "  - Source: $SOURCE_BRANCH"
echo "  - Target: $TARGET_BRANCH"
if [ -n "$SOURCE_COMMIT_ID" ]; then
    echo "  - Source Commit: $SOURCE_COMMIT_ID"
fi
if [ -n "$TARGET_COMMIT_ID" ]; then
    echo "  - Target Commit: $TARGET_COMMIT_ID"
fi

# Obtener todos los cambios de la PR
echo "📝 Getting all changes..."
ALL_CHANGES_FILE="/tmp/pr_all_changes.diff"

# Determinar el método más apropiado para obtener los cambios
# Azure DevOps hace checkout del merge commit de la PR
DIFF_METHOD=""

# Método 1: usar commit IDs específicos (funciona incluso con forks/otros repos)
if [ -n "$TARGET_COMMIT_ID" ] && [ -n "$SOURCE_COMMIT_ID" ]; then
    echo "Using commit IDs: $TARGET_COMMIT_ID..$SOURCE_COMMIT_ID"
    if git diff "$TARGET_COMMIT_ID" "$SOURCE_COMMIT_ID" > "$ALL_CHANGES_FILE" 2>/dev/null; then
        CHANGED_FILES=$(git diff --name-only "$TARGET_COMMIT_ID" "$SOURCE_COMMIT_ID" | tr '\n' ', ' | sed 's/,$//')
        FILE_COUNT=$(git diff --name-only "$TARGET_COMMIT_ID" "$SOURCE_COMMIT_ID" | wc -l | tr -d ' ')
        DIFF_METHOD="commit-ids"
    else
        echo "⚠️ Commit IDs not available, falling back to HEAD^1"
        git diff HEAD^1 HEAD > "$ALL_CHANGES_FILE"
        CHANGED_FILES=$(git diff --name-only HEAD^1 HEAD | tr '\n' ', ' | sed 's/,$//')
        FILE_COUNT=$(git diff --name-only HEAD^1 HEAD | wc -l | tr -d ' ')
        DIFF_METHOD="merge-parent"
    fi
# Método 2: HEAD^1 (padre del merge commit = target branch)
elif git rev-parse HEAD^1 > /dev/null 2>&1; then
    echo "Using HEAD^1..HEAD (merge commit parent)"
    git diff HEAD^1 HEAD > "$ALL_CHANGES_FILE"
    CHANGED_FILES=$(git diff --name-only HEAD^1 HEAD | tr '\n' ', ' | sed 's/,$//')
    FILE_COUNT=$(git diff --name-only HEAD^1 HEAD | wc -l | tr -d ' ')
    DIFF_METHOD="merge-parent"
# Método 3: último commit (fallback)
else
    echo "⚠️ Fallback: Using last commit"
    git show HEAD > "$ALL_CHANGES_FILE"
    CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD | tr '\n' ', ' | sed 's/,$//')
    FILE_COUNT=$(git diff-tree --no-commit-id --name-only -r HEAD | wc -l | tr -d ' ')
    DIFF_METHOD="last-commit"
fi

echo "📊 Files changed: $FILE_COUNT (method: $DIFF_METHOD)"

# Si no hay cambios, salir con error
if [ "$FILE_COUNT" -eq 0 ] || [ -z "$FILE_COUNT" ] || [ ! -s "$ALL_CHANGES_FILE" ]; then
    echo "❌ Error: No changes detected in PR"
    echo "This might indicate a problem with git history or branch references"
    exit 1
fi

# Crear directorio de logs si no existe
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

# Crear prompt para Copilot que analice toda la PR
PROMPT="You are an expert code reviewer. Review the following Pull Request changes and provide individual recommendations.

**Pull Request Information:**
- PR Number: #$PR_ID
- Source Branch: $SOURCE_BRANCH
- Target Branch: $TARGET_BRANCH
- Files Changed: $FILE_COUNT ($CHANGED_FILES)

**Your Task:**
Analyze all the code changes and provide specific, actionable recommendations. For EACH issue you find, provide:

1. The file path and line number(s) where the issue occurs
2. A clear description of the issue
3. The severity level (CRITICAL, HIGH, MEDIUM, LOW)
4. A category (e.g., Security, Performance, Best Practices, Code Quality, etc.)
5. A snippet of the problematic code
6. A concrete recommendation on how to fix it

**IMPORTANT OUTPUT FORMAT:**
Structure your response with clear separators for each recommendation. Use this EXACT format:

---RECOMMENDATION---
FILE: path/to/file.ext
LINE: 42
SEVERITY: HIGH
CATEGORY: Security
DESCRIPTION: Clear description of the issue
CODE_SNIPPET:
\`\`\`
// The problematic code here
\`\`\`
RECOMMENDATION: Specific actionable fix
---END---

(Repeat for each recommendation)

**Guidelines:**
- Focus on: security vulnerabilities, performance issues, bugs, code smells, best practices violations
- Be specific with file paths and line numbers
- Provide code snippets showing the issue
- Give actionable recommendations, not just observations
- Prioritize critical and high-severity issues

Here are the changes to review:
"

# Guardar el prompt y los cambios en archivos temporales para debug
echo "$PROMPT" > /tmp/copilot_prompt.txt
echo "" >> /tmp/copilot_prompt.txt
cat "$ALL_CHANGES_FILE" >> /tmp/copilot_prompt.txt

# Ejecutar Copilot con el diff completo
echo "🤖 Running Copilot analysis..."
echo "(This may take a few moments depending on the size of the changes)"

cat /tmp/copilot_prompt.txt | copilot \
    --model "${MODEL:-claude-sonnet-4}" > "$LOG_DIR/copilot_raw_output.md" 2>&1 || {
    echo "⚠️ Error executing Copilot CLI"
    echo "**Analysis Error:** Could not complete Copilot analysis. Check logs in $LOG_DIR" > "$REVIEW_OUTPUT"
    exit 1
}

# Guardar la salida cruda para procesamiento posterior
cp "$LOG_DIR/copilot_raw_output.md" "$LOG_DIR/copilot_recommendations.md"

# Crear el reporte final resumido
echo "📄 Generating final report..."

cat > "$REVIEW_OUTPUT" << EOF
# PR Review Report

**Pull Request:** #$PR_ID
**Source Branch:** $SOURCE_BRANCH
**Target Branch:** $TARGET_BRANCH
**Date:** $(date)
**Files Changed:** $FILE_COUNT
**Review Model:** ${MODEL:-claude-sonnet-4}

---

## 🤖 Copilot Code Review

EOF

# Agregar el análisis de Copilot
cat "$LOG_DIR/copilot_raw_output.md" >> "$REVIEW_OUTPUT"

# Agregar footer
cat >> "$REVIEW_OUTPUT" << EOF

---

## 📊 Review Summary

- **Total Files Reviewed:** $FILE_COUNT
- **Changed Files:** $CHANGED_FILES
- **Analysis Model:** ${MODEL:-claude-sonnet-4}

---

*Report generated automatically by GitHub Copilot CLI*
*Individual recommendations have been posted as PR comments*
EOF

echo ""
echo "✅ Analysis completed successfully"
echo "📊 Files reviewed: $FILE_COUNT"
echo "📄 Report saved to: $REVIEW_OUTPUT"
echo "📄 Recommendations for parsing saved to: $LOG_DIR/copilot_recommendations.md"

# Limpiar archivos temporales
rm -f "$ALL_CHANGES_FILE"
