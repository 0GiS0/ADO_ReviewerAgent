#!/bin/bash
set -e

echo "🔍 Analyzing PR changes with Copilot (Full Diff via API)..."

# Verificar que Copilot CLI esté instalado
if ! command -v copilot &> /dev/null; then
    echo "❌ Error: copilot CLI no está instalado"
    exit 1
fi

# Verificar que jq esté instalado
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq no está instalado"
    echo "Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq || {
        echo "Could not install jq"
        exit 1
    }
fi

# Variables de entorno requeridas
ORG_URL="${SYSTEM_COLLECTIONURI}"
PROJECT="${SYSTEM_TEAMPROJECT}"
REPO_ID="${BUILD_REPOSITORY_ID}"
REPO_NAME="${BUILD_REPOSITORY_NAME}"
PR_ID="${SYSTEM_PULLREQUEST_PULLREQUESTID}"
SOURCE_BRANCH="${SYSTEM_PULLREQUEST_SOURCEBRANCH#refs/heads/}"
TARGET_BRANCH="${SYSTEM_PULLREQUEST_TARGETBRANCH#refs/heads/}"

# Validar variables
if [ -z "$ORG_URL" ] || [ -z "$PROJECT" ] || [ -z "$REPO_ID" ] || [ -z "$PR_ID" ]; then
    echo "❌ Error: Variables de Azure DevOps no configuradas"
    echo "ORG_URL: $ORG_URL"
    echo "PROJECT: $PROJECT"
    echo "REPO_ID: $REPO_ID"
    echo "PR_ID: $PR_ID"
    exit 1
fi

echo "📋 PR Information:"
echo "  - Repository: $REPO_NAME"
echo "  - Repository ID: $REPO_ID"
echo "  - PR #$PR_ID"
echo "  - Source: $SOURCE_BRANCH"
echo "  - Target: $TARGET_BRANCH"

# Configurar autenticación
if [ -n "$SYSTEM_ACCESSTOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $SYSTEM_ACCESSTOKEN"
    echo "  - Auth: Using System.AccessToken"
elif [ -n "$AZURE_DEVOPS_EXT_PAT" ]; then
    AUTH_HEADER="Authorization: Basic $(echo -n ":$AZURE_DEVOPS_EXT_PAT" | base64)"
    echo "  - Auth: Using PAT"
else
    echo "❌ Error: No authentication token available"
    exit 1
fi

# Crear directorio de logs
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

# Obtener información completa de la PR
echo ""
echo "📝 Getting PR details from Azure DevOps API..."
PR_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}?api-version=7.0"
PR_INFO=$(curl -s -H "$AUTH_HEADER" "$PR_URL")

# Guardar PR info para debug
echo "$PR_INFO" > "$LOG_DIR/pr_info.json"

# Extraer commits IDs
SOURCE_COMMIT=$(echo "$PR_INFO" | jq -r '.lastMergeSourceCommit.commitId // .sourceRefName')
TARGET_COMMIT=$(echo "$PR_INFO" | jq -r '.lastMergeTargetCommit.commitId // .targetRefName')

echo "  - Source Commit: $SOURCE_COMMIT"
echo "  - Target Commit: $TARGET_COMMIT"

# Obtener el diff completo usando la API de commits
echo ""
echo "📄 Getting full diff from Azure DevOps..."
DIFF_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/diffs/commits?baseVersion=${TARGET_COMMIT}&targetVersion=${SOURCE_COMMIT}&api-version=7.0"

echo "Fetching diff from API..."
DIFF_RESPONSE=$(curl -s -H "$AUTH_HEADER" "$DIFF_URL")

# Guardar respuesta completa para debug
echo "$DIFF_RESPONSE" > "$LOG_DIR/diff_response.json"

# Verificar si hay cambios
CHANGE_COUNT=$(echo "$DIFF_RESPONSE" | jq -r '.changes | length')

if [ -z "$CHANGE_COUNT" ] || [ "$CHANGE_COUNT" = "null" ] || [ "$CHANGE_COUNT" -eq 0 ]; then
    echo "❌ Error: No se pudieron obtener los cambios de la PR"
    echo "Response: $DIFF_RESPONSE" | head -20
    exit 1
fi

echo "✅ Found $CHANGE_COUNT changed files"

# Construir un diff legible para Copilot
echo ""
echo "📝 Building diff summary for Copilot..."

DIFF_SUMMARY="$LOG_DIR/diff_summary.txt"
echo "=== PULL REQUEST DIFF ===" > "$DIFF_SUMMARY"
echo "" >> "$DIFF_SUMMARY"
echo "Repository: $REPO_NAME" >> "$DIFF_SUMMARY"
echo "PR #$PR_ID: $SOURCE_BRANCH → $TARGET_BRANCH" >> "$DIFF_SUMMARY"
echo "Files changed: $CHANGE_COUNT" >> "$DIFF_SUMMARY"
echo "" >> "$DIFF_SUMMARY"

# Procesar cada archivo cambiado
echo "$DIFF_RESPONSE" | jq -r '.changes[] | 
{
  path: .item.path,
  changeType: .changeType,
  originalPath: (.item.originalPath // "N/A")
} | 
"File: \(.path)\nChange Type: \(.changeType)\nOriginal Path: \(.originalPath)\n---"' >> "$DIFF_SUMMARY"

# Lista de archivos para el resumen
CHANGED_FILES=$(echo "$DIFF_RESPONSE" | jq -r '.changes[].item.path' | sed 's|^/||' | tr '\n' ',' | sed 's/,$//')

echo "Files: $CHANGED_FILES"

# Obtener commits de la PR para contexto adicional
echo ""
echo "📝 Getting commit messages..."
COMMITS_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}/commits?api-version=7.0"
COMMITS_DATA=$(curl -s -H "$AUTH_HEADER" "$COMMITS_URL")

COMMIT_MESSAGES=$(echo "$COMMITS_DATA" | jq -r '.value[]? | "- \(.comment)"' | head -15)

# Para cada archivo, intentar obtener el contenido del cambio
echo ""
echo "📄 Attempting to get file contents and diffs..."

ALL_CHANGES_TEXT="$LOG_DIR/all_changes.diff"
echo "=== DETAILED CHANGES ===" > "$ALL_CHANGES_TEXT"
echo "" >> "$ALL_CHANGES_TEXT"

# Iterar sobre los primeros archivos (limitar para no sobrecargar)
FILE_INDEX=0
MAX_FILES=20

echo "$DIFF_RESPONSE" | jq -c '.changes[] | select(.changeType != "delete") | .item' | while IFS= read -r item; do
    FILE_INDEX=$((FILE_INDEX + 1))
    
    if [ $FILE_INDEX -gt $MAX_FILES ]; then
        echo "⚠️ Limiting to first $MAX_FILES files to avoid timeout"
        break
    fi
    
    FILE_PATH=$(echo "$item" | jq -r '.path' | sed 's|^/||')
    OBJECT_ID=$(echo "$item" | jq -r '.objectId')
    
    echo "  Processing: $FILE_PATH"
    
    # Obtener contenido del archivo
    BLOB_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/blobs/${OBJECT_ID}?api-version=7.0&\$format=text"
    
    echo "" >> "$ALL_CHANGES_TEXT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$ALL_CHANGES_TEXT"
    echo "FILE: $FILE_PATH" >> "$ALL_CHANGES_TEXT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$ALL_CHANGES_TEXT"
    
    FILE_CONTENT=$(curl -s -H "$AUTH_HEADER" "$BLOB_URL" 2>/dev/null || echo "Could not fetch content")
    
    # Limitar tamaño de archivo para evitar sobrecarga
    LINE_COUNT=$(echo "$FILE_CONTENT" | wc -l)
    if [ "$LINE_COUNT" -gt 500 ]; then
        echo "$FILE_CONTENT" | head -250 >> "$ALL_CHANGES_TEXT"
        echo "... [File truncated - showing first 250 lines of $LINE_COUNT total] ..." >> "$ALL_CHANGES_TEXT"
        echo "$FILE_CONTENT" | tail -250 >> "$ALL_CHANGES_TEXT"
    else
        echo "$FILE_CONTENT" >> "$ALL_CHANGES_TEXT"
    fi
    
    echo "" >> "$ALL_CHANGES_TEXT"
done

echo "✅ Collected changes for analysis"

# Crear prompt para Copilot
PROMPT="You are an expert code reviewer. Review the following Pull Request changes and provide individual recommendations.

**Pull Request Information:**
- Repository: $REPO_NAME
- PR Number: #$PR_ID
- Source Branch: $SOURCE_BRANCH
- Target Branch: $TARGET_BRANCH
- Files Changed: $CHANGE_COUNT

**Recent Commit Messages:**
$COMMIT_MESSAGES

**Changed Files:**
$(cat "$DIFF_SUMMARY")

**File Contents:**
$(cat "$ALL_CHANGES_TEXT")

**Your Task:**
Analyze the code changes and provide specific, actionable code review recommendations.

**IMPORTANT OUTPUT FORMAT:**
Structure your response with clear separators for each recommendation. Use this EXACT format:

---RECOMMENDATION---
FILE: path/to/file.ext
LINE: (line number or range, or 'N/A')
SEVERITY: CRITICAL/HIGH/MEDIUM/LOW
CATEGORY: Security/Performance/Best Practices/Code Quality/Bug/etc
DESCRIPTION: Clear description of the issue
CODE_SNIPPET:
\`\`\`
// The problematic code or pattern
\`\`\`
RECOMMENDATION: Specific actionable fix or improvement
---END---

**Guidelines:**
- Focus on: security vulnerabilities, performance issues, bugs, code smells, best practices violations
- Be specific with file paths and line numbers when possible
- Provide actionable recommendations, not just observations
- Prioritize critical and high-severity issues
- Consider the context from commit messages

Please analyze these changes and provide your recommendations.
"

echo "$PROMPT" > "$LOG_DIR/copilot_prompt.txt"

# Ejecutar Copilot con el análisis completo
echo ""
echo "🤖 Running Copilot analysis..."
echo "(This may take a few moments...)"

echo "$PROMPT" | copilot \
    --model "${MODEL:-claude-sonnet-4}" > "$LOG_DIR/copilot_raw_output.md" 2>&1 || {
    echo "⚠️ Error executing Copilot CLI"
    echo "**Analysis Error:** Could not complete Copilot analysis. Check logs in $LOG_DIR" > "$REVIEW_OUTPUT"
    exit 1
}

# Guardar la salida para procesamiento posterior
cp "$LOG_DIR/copilot_raw_output.md" "$LOG_DIR/copilot_recommendations.md"

# Crear el reporte final
echo ""
echo "📄 Generating final report..."

cat > "$REVIEW_OUTPUT" << EOF
# PR Review Report

**Repository:** $REPO_NAME
**Pull Request:** #$PR_ID
**Source Branch:** $SOURCE_BRANCH
**Target Branch:** $TARGET_BRANCH
**Date:** $(date)
**Files Changed:** $CHANGE_COUNT
**Review Model:** ${MODEL:-claude-sonnet-4}

---

## 🤖 Copilot Code Review

EOF

cat "$LOG_DIR/copilot_raw_output.md" >> "$REVIEW_OUTPUT"

cat >> "$REVIEW_OUTPUT" << EOF

---

## 📊 Review Summary

- **Total Files Reviewed:** $CHANGE_COUNT
- **Changed Files:** $CHANGED_FILES
- **Analysis Model:** ${MODEL:-claude-sonnet-4}

---

*Report generated automatically by GitHub Copilot CLI*
*Individual recommendations have been posted as PR comments*
EOF

echo ""
echo "✅ Analysis completed successfully"
echo "📊 Files reviewed: $CHANGE_COUNT"
echo "📄 Report saved to: $REVIEW_OUTPUT"
echo "📄 Recommendations saved to: $LOG_DIR/copilot_recommendations.md"
