#!/bin/bash
set -e

echo "🔍 Analyzing PR changes with Copilot..."

# Verificar herramientas
if ! command -v copilot &> /dev/null; then
    echo "❌ Error: copilot CLI no está instalado"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq no está instalado"
    exit 1
fi

# Variables de entorno
ORG_URL="${SYSTEM_COLLECTIONURI}"
PROJECT="${SYSTEM_TEAMPROJECT}"
SOURCE_REPO_ID="${SOURCE_REPO_ID}"
SOURCE_REPO_NAME="${SOURCE_REPO_NAME}"
PR_ID="${SYSTEM_PULLREQUEST_PULLREQUESTID}"
SOURCE_BRANCH="${SYSTEM_PULLREQUEST_SOURCEBRANCH#refs/heads/}"
TARGET_BRANCH="${SYSTEM_PULLREQUEST_TARGETBRANCH#refs/heads/}"

echo "📋 PR Information:"
echo "  - Source Repository: $SOURCE_REPO_NAME"
echo "  - Source Branch: $SOURCE_BRANCH"
echo "  - Target Branch: $TARGET_BRANCH"
echo "  - PR #$PR_ID"

# Validar variables
if [ -z "$ORG_URL" ] || [ -z "$PROJECT" ] || [ -z "$SOURCE_REPO_ID" ] || [ -z "$PR_ID" ]; then
    echo "❌ Error: Variables requeridas no configuradas"
    echo "ORG_URL: $ORG_URL"
    echo "PROJECT: $PROJECT"
    echo "SOURCE_REPO_ID: $SOURCE_REPO_ID"
    echo "PR_ID: $PR_ID"
    exit 1
fi

# Configurar autenticación
if [ -n "$AZURE_DEVOPS_EXT_PAT" ]; then
    AUTH_HEADER="Authorization: Basic $(echo -n ":$AZURE_DEVOPS_EXT_PAT" | base64)"
    echo "  - Auth: Using PAT"
elif [ -n "$SYSTEM_ACCESSTOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $SYSTEM_ACCESSTOKEN"
    echo "  - Auth: Using System.AccessToken"
else
    echo "❌ Error: No authentication available"
    exit 1
fi

# Crear directorio de logs
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

echo ""
echo "📝 Getting commits from branches via API..."

# Obtener el commit más reciente del source branch
SOURCE_BRANCH_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${SOURCE_REPO_ID}/refs?filter=heads/${SOURCE_BRANCH}&api-version=7.0"
SOURCE_REF=$(curl -s -H "$AUTH_HEADER" "$SOURCE_BRANCH_URL")
SOURCE_COMMIT=$(echo "$SOURCE_REF" | jq -r '.value[0].objectId // empty')

if [ -z "$SOURCE_COMMIT" ]; then
    echo "❌ Error: No se pudo obtener el commit del source branch: $SOURCE_BRANCH"
    echo "Response: $SOURCE_REF"
    exit 1
fi

echo "  - Source Commit ($SOURCE_BRANCH): $SOURCE_COMMIT"

# Obtener el commit más reciente del target branch
TARGET_BRANCH_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${SOURCE_REPO_ID}/refs?filter=heads/${TARGET_BRANCH}&api-version=7.0"
TARGET_REF=$(curl -s -H "$AUTH_HEADER" "$TARGET_BRANCH_URL")
TARGET_COMMIT=$(echo "$TARGET_REF" | jq -r '.value[0].objectId // empty')

if [ -z "$TARGET_COMMIT" ]; then
    echo "❌ Error: No se pudo obtener el commit del target branch: $TARGET_BRANCH"
    echo "Response: $TARGET_REF"
    exit 1
fi

echo "  - Target Commit ($TARGET_BRANCH): $TARGET_COMMIT"

echo ""
echo "📄 Getting diff between branches..."

# Obtener el diff entre target y source
DIFF_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${SOURCE_REPO_ID}/diffs/commits?baseVersion=${TARGET_COMMIT}&targetVersion=${SOURCE_COMMIT}&api-version=7.0"

echo "  - Diff URL: ${DIFF_URL}"

DIFF_RESPONSE=$(curl -s -H "$AUTH_HEADER" "$DIFF_URL")

# Guardar respuesta para debug
echo "$DIFF_RESPONSE" > "$LOG_DIR/diff_response.json"

# Contar cambios
CHANGE_COUNT=$(echo "$DIFF_RESPONSE" | jq -r '.changes | length')

if [ -z "$CHANGE_COUNT" ] || [ "$CHANGE_COUNT" = "null" ] || [ "$CHANGE_COUNT" -eq 0 ]; then
    echo "❌ Error: No se encontraron cambios entre $TARGET_BRANCH y $SOURCE_BRANCH"
    echo "Diff response: $(echo "$DIFF_RESPONSE" | head -20)"
    exit 1
fi

echo "✅ Found $CHANGE_COUNT changed files"

# Construir resumen de cambios
DIFF_SUMMARY="$LOG_DIR/diff_summary.txt"
echo "=== BRANCH COMPARISON ===" > "$DIFF_SUMMARY"
echo "" >> "$DIFF_SUMMARY"
echo "Repository: $SOURCE_REPO_NAME" >> "$DIFF_SUMMARY"
echo "Comparing: $TARGET_BRANCH → $SOURCE_BRANCH" >> "$DIFF_SUMMARY"
echo "Files changed: $CHANGE_COUNT" >> "$DIFF_SUMMARY"
echo "" >> "$DIFF_SUMMARY"

# Lista de archivos cambiados
CHANGED_FILES=$(echo "$DIFF_RESPONSE" | jq -r '.changes[].item.path' | sed 's|^/||' | tr '\n' ',' | sed 's/,$//')

echo "Files: $CHANGED_FILES"

# Resumen de cambios por tipo
echo "" >> "$DIFF_SUMMARY"
echo "Changes by type:" >> "$DIFF_SUMMARY"
echo "$DIFF_RESPONSE" | jq -r '.changes[] | "\(.changeType): \(.item.path)"' >> "$DIFF_SUMMARY"

echo ""
echo "📄 Getting file contents for changed files..."

ALL_CHANGES_TEXT="$LOG_DIR/all_changes.diff"
echo "=== DETAILED FILE CHANGES ===" > "$ALL_CHANGES_TEXT"
echo "" >> "$ALL_CHANGES_TEXT"
echo "Branch Comparison: $TARGET_BRANCH → $SOURCE_BRANCH" >> "$ALL_CHANGES_TEXT"
echo "" >> "$ALL_CHANGES_TEXT"

# Procesar archivos cambiados
FILE_INDEX=0
MAX_FILES=20

echo "$DIFF_RESPONSE" | jq -c '.changes[]' | while IFS= read -r change; do
    FILE_INDEX=$((FILE_INDEX + 1))
    
    if [ $FILE_INDEX -gt $MAX_FILES ]; then
        echo "⚠️ Limiting to first $MAX_FILES files"
        break
    fi
    
    FILE_PATH=$(echo "$change" | jq -r '.item.path' | sed 's|^/||')
    CHANGE_TYPE=$(echo "$change" | jq -r '.changeType')
    OBJECT_ID=$(echo "$change" | jq -r '.item.objectId')
    
    echo "  [$FILE_INDEX/$CHANGE_COUNT] $CHANGE_TYPE: $FILE_PATH"
    
    echo "" >> "$ALL_CHANGES_TEXT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$ALL_CHANGES_TEXT"
    echo "FILE: $FILE_PATH" >> "$ALL_CHANGES_TEXT"
    echo "CHANGE TYPE: $CHANGE_TYPE" >> "$ALL_CHANGES_TEXT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$ALL_CHANGES_TEXT"
    
    # Si el archivo fue eliminado, no intentar obtener contenido
    if [ "$CHANGE_TYPE" = "delete" ]; then
        echo "[File deleted]" >> "$ALL_CHANGES_TEXT"
        continue
    fi
    
    # Obtener contenido del archivo desde el source commit
    BLOB_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${SOURCE_REPO_ID}/blobs/${OBJECT_ID}?api-version=7.0&\$format=text"
    
    FILE_CONTENT=$(curl -s -H "$AUTH_HEADER" "$BLOB_URL" 2>/dev/null || echo "[Could not fetch content]")
    
    # Limitar tamaño para evitar sobrecargar
    LINE_COUNT=$(echo "$FILE_CONTENT" | wc -l | tr -d ' ')
    
    if [ "$LINE_COUNT" -gt 500 ]; then
        echo "$FILE_CONTENT" | head -250 >> "$ALL_CHANGES_TEXT"
        echo "" >> "$ALL_CHANGES_TEXT"
        echo "... [File truncated - showing first 250 lines of $LINE_COUNT total] ..." >> "$ALL_CHANGES_TEXT"
        echo "" >> "$ALL_CHANGES_TEXT"
        echo "$FILE_CONTENT" | tail -250 >> "$ALL_CHANGES_TEXT"
    else
        echo "$FILE_CONTENT" >> "$ALL_CHANGES_TEXT"
    fi
    
    echo "" >> "$ALL_CHANGES_TEXT"
done

echo ""
echo "✅ Collected changes for analysis"

# Crear prompt para Copilot
PROMPT="You are an expert code reviewer. Review the following changes that will be merged from the source branch to the target branch.

**Branch Comparison:**
- Repository: $SOURCE_REPO_NAME
- Source Branch: $SOURCE_BRANCH (changes to be merged)
- Target Branch: $TARGET_BRANCH (destination)
- Files Changed: $CHANGE_COUNT
- PR #$PR_ID

**Changed Files:**
$(cat "$DIFF_SUMMARY")

**File Contents:**
$(cat "$ALL_CHANGES_TEXT")

**Your Task:**
Analyze the code changes that will be introduced or modified when merging from $SOURCE_BRANCH to $TARGET_BRANCH. Provide specific, actionable code review recommendations.

**IMPORTANT OUTPUT FORMAT:**
Use this EXACT format for each recommendation:

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

**Focus on:**
- Security vulnerabilities
- Performance issues
- Bugs and potential errors
- Code quality and best practices
- Breaking changes
- Missing documentation
- Test coverage

Please analyze these changes and provide your recommendations.
"

echo "$PROMPT" > "$LOG_DIR/copilot_prompt.txt"

# Ejecutar Copilot
echo ""
echo "🤖 Running Copilot analysis..."

echo "$PROMPT" | copilot \
    --model "${MODEL:-claude-sonnet-4}" > "$LOG_DIR/copilot_raw_output.md" 2>&1 || {
    echo "⚠️ Error executing Copilot CLI"
    echo "**Analysis Error:** Could not complete analysis. Check logs in $LOG_DIR" > "$REVIEW_OUTPUT"
    exit 1
}

cp "$LOG_DIR/copilot_raw_output.md" "$LOG_DIR/copilot_recommendations.md"

# Crear reporte final
echo ""
echo "📄 Generating final report..."

cat > "$REVIEW_OUTPUT" << EOF
# PR Review Report

**Repository:** $SOURCE_REPO_NAME
**Source Branch:** $SOURCE_BRANCH (changes to merge)
**Target Branch:** $TARGET_BRANCH (destination)
**Pull Request:** #$PR_ID
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
- **Branch Comparison:** $TARGET_BRANCH → $SOURCE_BRANCH

---

*Report generated automatically by GitHub Copilot CLI*
*Individual recommendations have been posted as PR comments*
EOF

echo ""
echo "✅ Analysis completed successfully"
echo "📊 Files reviewed: $CHANGE_COUNT"
echo "📄 Report saved to: $REVIEW_OUTPUT"
echo "📄 Recommendations saved to: $LOG_DIR/copilot_recommendations.md"
