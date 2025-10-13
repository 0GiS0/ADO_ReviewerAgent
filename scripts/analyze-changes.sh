#!/bin/bash
set -e

echo "🔍 Analyzing PR changes with Copilot..."

# Verificar que Copilot CLI esté instalado
if ! command -v copilot &> /dev/null; then
    echo "❌ Error: copilot CLI no está instalado"
    exit 1
fi

# Obtener información de la PR
TARGET_BRANCH=${System.PullRequest.TargetBranch#refs/heads/}
SOURCE_BRANCH=${System.PullRequest.SourceBranch#refs/heads/}
PR_ID=$(System.PullRequest.PullRequestId)

echo "📋 PR Information:"
echo "  - PR #$PR_ID"
echo "  - Source: $SOURCE_BRANCH"
echo "  - Target: $TARGET_BRANCH"

# Obtener todos los cambios de la PR
echo "📝 Getting all changes..."
ALL_CHANGES_FILE="/tmp/pr_all_changes.diff"
git diff origin/$TARGET_BRANCH...HEAD > "$ALL_CHANGES_FILE"

# Obtener lista de archivos modificados
CHANGED_FILES=$(git diff --name-only origin/$TARGET_BRANCH...HEAD | tr '\n' ', ' | sed 's/,$//')
FILE_COUNT=$(git diff --name-only origin/$TARGET_BRANCH...HEAD | wc -l | tr -d ' ')

echo "📊 Files changed: $FILE_COUNT"

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
4. The relevant code snippet that has the issue
5. A specific recommendation on how to fix it

**All Changes:**
\`\`\`diff
$(cat "$ALL_CHANGES_FILE")
\`\`\`

**Output Format:**
For each recommendation, use this EXACT format (this is critical for parsing):

---RECOMMENDATION---
FILE: <file_path>
LINE: <line_number or range>
SEVERITY: <CRITICAL|HIGH|MEDIUM|LOW>
CATEGORY: <Bugs|Security|Performance|Best Practices|Maintainability|Testing>
DESCRIPTION: <clear description of the issue>
CODE_SNIPPET:
\`\`\`
<the relevant code snippet>
\`\`\`
RECOMMENDATION: <specific actionable recommendation>
---END---

**Instructions:**
- Be specific and reference exact file paths and line numbers
- Include the actual code snippet for each issue
- Focus on meaningful issues that should be addressed
- If code is good, you can mention it but don't create fake issues
- Organize findings by severity"

echo "🤖 Running Copilot analysis on entire PR..."
echo "   Model: ${MODEL:-claude-sonnet-4}"

# Ejecutar Copilot con todos los cambios
copilot -p "$PROMPT" \
    --allow-all-tools \
    --log-level all \
    --log-dir "$LOG_DIR" \
    --model "${MODEL:-claude-sonnet-4}" > "$LOG_DIR/copilot_raw_output.md" 2>&1 || {
    echo "⚠️ Error executing Copilot CLI"
    echo "**Analysis Error:** Could not complete Copilot analysis. Check logs in $LOG_DIR" > $(REVIEW_OUTPUT)
    exit 1
}

# Guardar la salida cruda para procesamiento posterior
cp "$LOG_DIR/copilot_raw_output.md" "$LOG_DIR/copilot_recommendations.md"

# Crear el reporte final resumido
echo "📄 Generating final report..."

cat > $(REVIEW_OUTPUT) << EOF
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
cat "$LOG_DIR/copilot_raw_output.md" >> $(REVIEW_OUTPUT)

# Agregar footer
cat >> $(REVIEW_OUTPUT) << EOF

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
echo "📄 Report saved to: $(REVIEW_OUTPUT)"
echo "📄 Recommendations for parsing saved to: $LOG_DIR/copilot_recommendations.md"

# Limpiar archivos temporales
rm -f "$ALL_CHANGES_FILE"
