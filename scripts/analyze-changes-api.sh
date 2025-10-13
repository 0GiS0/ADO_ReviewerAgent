#!/bin/bash
set -e

echo "🔍 Analyzing PR changes with Copilot (using Azure DevOps API)..."

# Verificar que Copilot CLI esté instalado
if ! command -v copilot &> /dev/null; then
    echo "❌ Error: copilot CLI no está instalado"
    exit 1
fi

# Variables de entorno requeridas
ORG_URL="${SYSTEM_COLLECTIONURI}"
PROJECT="${SYSTEM_TEAMPROJECT}"
REPO_ID="${BUILD_REPOSITORY_ID}"
REPO_NAME="${BUILD_REPOSITORY_NAME}"
PR_ID="${SYSTEM_PULLREQUEST_PULLREQUESTID}"
SOURCE_BRANCH="${SYSTEM_PULLREQUEST_SOURCEBRANCH#refs/heads/}"
TARGET_BRANCH="${SYSTEM_PULLREQUEST_TARGETBRANCH#refs/heads/}"

# Archivo de salida del reporte

# Validar variables
if [ -z "$ORG_URL" ] || [ -z "$PROJECT" ] || [ -z "$REPO_ID" ] || [ -z "$PR_ID" ]; then
    echo "❌ Error: Variables de Azure DevOps no configuradas"
    exit 1
fi

echo "📋 PR Information:"
echo "  - Repository: $REPO_NAME"
echo "  - PR #$PR_ID"
echo "  - Source: $SOURCE_BRANCH"
echo "  - Target: $TARGET_BRANCH"

# Configurar autenticación
if [ -n "$SYSTEM_ACCESSTOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $SYSTEM_ACCESSTOKEN"
elif [ -n "$AZURE_DEVOPS_EXT_PAT" ]; then
    AUTH_HEADER="Authorization: Basic $(echo -n ":$AZURE_DEVOPS_EXT_PAT" | base64)"
else
    echo "❌ Error: No authentication token available"
    exit 1
fi

# Crear directorio de logs
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

# Obtener las iteraciones de la PR
echo "📝 Getting PR changes from Azure DevOps API..."
ITERATIONS_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}/iterations?api-version=7.0"
PR_DATA=$(curl -s -H "$AUTH_HEADER" "$ITERATIONS_URL")

# Obtener la última iteración
LATEST_ITERATION=$(echo "$PR_DATA" | jq -r '.value | sort_by(.id) | last | .id')

if [ -z "$LATEST_ITERATION" ] || [ "$LATEST_ITERATION" = "null" ]; then
    echo "❌ Error: Could not get PR iterations"
    exit 1
fi

echo "Latest iteration: $LATEST_ITERATION"

# Obtener los cambios de la iteración
CHANGES_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}/iterations/${LATEST_ITERATION}/changes?api-version=7.0"
CHANGES_DATA=$(curl -s -H "$AUTH_HEADER" "$CHANGES_URL")

# Guardar los cambios en formato JSON para análisis
echo "$CHANGES_DATA" > "$LOG_DIR/pr_changes.json"

# Extraer información de archivos cambiados
CHANGED_FILES=$(echo "$CHANGES_DATA" | jq -r '.changeEntries[]? | select(.changeType != "delete") | .item.path' | sed 's/^\///' | tr '\n' ',' | sed 's/,$//')
FILE_COUNT=$(echo "$CHANGES_DATA" | jq -r '[.changeEntries[]? | select(.changeType != "delete")] | length')

echo "📊 Files changed: $FILE_COUNT"

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "❌ Error: No changes detected in PR"
    exit 1
fi

# Crear un resumen textual de los cambios para Copilot
echo "📄 Preparing changes summary..."
CHANGES_SUMMARY="$LOG_DIR/changes_summary.txt"

echo "$CHANGES_DATA" | jq -r '.changeEntries[]? | 
  select(.changeType != "delete") | 
  "File: \(.item.path)\nChange Type: \(.changeType)\n---"' > "$CHANGES_SUMMARY"

# Obtener los commits de la PR para más contexto
COMMITS_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}/commits?api-version=7.0"
COMMITS_DATA=$(curl -s -H "$AUTH_HEADER" "$COMMITS_URL")

# Extraer mensajes de commits
COMMIT_MESSAGES=$(echo "$COMMITS_DATA" | jq -r '.value[]? | "- \(.comment)"' | head -10)

# Crear prompt para Copilot
PROMPT="You are an expert code reviewer. Review the following Pull Request and provide individual recommendations.

**Pull Request Information:**
- Repository: $REPO_NAME
- PR Number: #$PR_ID
- Source Branch: $SOURCE_BRANCH
- Target Branch: $TARGET_BRANCH
- Files Changed: $FILE_COUNT ($CHANGED_FILES)

**Recent Commits:**
$COMMIT_MESSAGES

**Files Modified:**
$(cat $CHANGES_SUMMARY)

**Your Task:**
Based on the files changed and the commit messages, provide specific, actionable code review recommendations.

**IMPORTANT OUTPUT FORMAT:**
Structure your response with clear separators for each recommendation. Use this EXACT format:

---RECOMMENDATION---
FILE: path/to/file.ext
LINE: (approximate line number or 'N/A' if not specific)
SEVERITY: HIGH/MEDIUM/LOW
CATEGORY: Security/Performance/Best Practices/Code Quality/etc
DESCRIPTION: Clear description of the issue or suggestion
CODE_SNIPPET:
\`\`\`
// If applicable, show expected code pattern
\`\`\`
RECOMMENDATION: Specific actionable fix or improvement
---END---

(Repeat for each recommendation)

**Guidelines:**
- Focus on: security vulnerabilities, performance issues, bugs, code smells, best practices violations
- Be specific with file paths
- Provide actionable recommendations, not just observations
- Prioritize critical and high-severity issues
- Consider the change types (add, edit, rename, delete)
- If you cannot access the actual file content, provide general recommendations based on file names and patterns

Please analyze these changes and provide your recommendations.
"

echo "$PROMPT" > "$LOG_DIR/copilot_prompt.txt"

# Ejecutar Copilot con el resumen de cambios
echo "🤖 Running Copilot analysis..."
echo "(Note: API-based review provides recommendations based on file names and changes)"

echo "$PROMPT" | copilot \
    --model "${MODEL:-claude-sonnet-4}" > "$LOG_DIR/copilot_raw_output.md" 2>&1 || {
    echo "⚠️ Error executing Copilot CLI"
    echo "**Analysis Error:** Could not complete Copilot analysis. Check logs in $LOG_DIR" > "$REVIEW_OUTPUT"
    exit 1
}

# Guardar la salida para procesamiento posterior
cp "$LOG_DIR/copilot_raw_output.md" "$LOG_DIR/copilot_recommendations.md"

# Crear el reporte final
echo "📄 Generating final report..."

cat > "$REVIEW_OUTPUT" << EOF
# PR Review Report

**Repository:** $REPO_NAME
**Pull Request:** #$PR_ID
**Source Branch:** $SOURCE_BRANCH
**Target Branch:** $TARGET_BRANCH
**Date:** $(date)
**Files Changed:** $FILE_COUNT
**Review Model:** ${MODEL:-claude-sonnet-4}
**Review Method:** Azure DevOps REST API

---

## 🤖 Copilot Code Review

EOF

cat "$LOG_DIR/copilot_raw_output.md" >> "$REVIEW_OUTPUT"

cat >> "$REVIEW_OUTPUT" << EOF

---

## 📊 Review Summary

- **Total Files Reviewed:** $FILE_COUNT
- **Changed Files:** $CHANGED_FILES
- **Analysis Model:** ${MODEL:-claude-sonnet-4}
- **Review Type:** API-based (file-level analysis)

---

*Report generated automatically by GitHub Copilot CLI*
*Individual recommendations have been posted as PR comments*
EOF

echo ""
echo "✅ Analysis completed successfully"
echo "📊 Files reviewed: $FILE_COUNT"
echo "📄 Report saved to: $REVIEW_OUTPUT"
echo "📄 Recommendations saved to: $LOG_DIR/copilot_recommendations.md"
