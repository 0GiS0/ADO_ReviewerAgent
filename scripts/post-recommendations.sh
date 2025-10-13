#!/bin/bash
set -e

echo "💬 Posting individual recommendations as PR comments..."

# Verificar argumentos
RECOMMENDATIONS_FILE=$1
ORG_URL=$2
PROJECT=$3
REPO_ID=$4
PR_ID=$5

if [ -z "$RECOMMENDATIONS_FILE" ] || [ -z "$ORG_URL" ] || [ -z "$PROJECT" ] || [ -z "$REPO_ID" ] || [ -z "$PR_ID" ]; then
    echo "Usage: $0 <recommendations_file> <org_url> <project> <repo_id> <pr_id>"
    echo "Note: AZURE_DEVOPS_EXT_PAT environment variable must be set"
    exit 1
fi

# Verificar que el PAT está configurado
if [ -z "$AZURE_DEVOPS_EXT_PAT" ]; then
    echo "❌ Error: AZURE_DEVOPS_EXT_PAT environment variable is not set"
    exit 1
fi

# Verificar que el archivo de recomendaciones existe
if [ ! -f "$RECOMMENDATIONS_FILE" ]; then
    echo "❌ Error: Recommendations file not found: $RECOMMENDATIONS_FILE"
    exit 1
fi

# URL de la API
API_URL="${ORG_URL}${PROJECT}/_apis/git/repositories/${REPO_ID}/pullRequests/${PR_ID}/threads?api-version=7.0"

echo "📋 Processing recommendations from: $RECOMMENDATIONS_FILE"

# Función para publicar un comentario
post_comment() {
    local file=$1
    local line=$2
    local severity=$3
    local category=$4
    local description=$5
    local code_snippet=$6
    local recommendation=$7
    
    # Emoji según severidad
    local emoji="💡"
    case $severity in
        CRITICAL) emoji="🔴" ;;
        HIGH) emoji="🟠" ;;
        MEDIUM) emoji="🟡" ;;
        LOW) emoji="🔵" ;;
    esac
    
    # Construir el contenido del comentario
    local comment_content="$emoji **$severity** - $category

**File:** \`$file\` (Line $line)

**Issue:**
$description

**Code:**
\`\`\`
$code_snippet
\`\`\`

**Recommendation:**
$recommendation

---
*Reviewed by GitHub Copilot*"

    # Escapar para JSON
    local escaped_content=$(echo "$comment_content" | jq -Rs .)
    
    # Crear JSON body
    local json_body=$(cat <<EOF
{
  "comments": [
    {
      "parentCommentId": 0,
      "content": $escaped_content,
      "commentType": 1
    }
  ],
  "status": 1
}
EOF
)
    
    # Publicar comentario
    local response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
      -H "Content-Type: application/json" \
      -H "Authorization: Basic $(echo -n ":$AZURE_DEVOPS_EXT_PAT" | base64)" \
      -d "$json_body")
    
    local http_code=$(echo "$response" | tail -n 1)
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo "  ✅ Posted comment for $file:$line"
        return 0
    else
        echo "  ⚠️ Failed to post comment for $file:$line (HTTP $http_code)"
        return 1
    fi
}

# Parsear el archivo de recomendaciones
echo "🔍 Parsing recommendations..."

comment_count=0
current_file=""
current_line=""
current_severity=""
current_category=""
current_description=""
current_code=""
current_recommendation=""
in_code_block=false
parsing_recommendation=false

while IFS= read -r line; do
    # Detectar inicio de recomendación
    if [[ "$line" == "---RECOMMENDATION---" ]]; then
        parsing_recommendation=true
        # Reset variables
        current_file=""
        current_line=""
        current_severity=""
        current_category=""
        current_description=""
        current_code=""
        current_recommendation=""
        in_code_block=false
        continue
    fi
    
    # Detectar fin de recomendación
    if [[ "$line" == "---END---" ]] && [ "$parsing_recommendation" = true ]; then
        parsing_recommendation=false
        
        # Validar que tenemos todos los campos necesarios
        if [ -n "$current_file" ] && [ -n "$current_line" ] && [ -n "$current_severity" ]; then
            echo "📝 Posting recommendation for $current_file:$current_line..."
            post_comment "$current_file" "$current_line" "$current_severity" "$current_category" \
                        "$current_description" "$current_code" "$current_recommendation"
            comment_count=$((comment_count + 1))
        fi
        continue
    fi
    
    # Parsear campos si estamos en una recomendación
    if [ "$parsing_recommendation" = true ]; then
        if [[ "$line" =~ ^FILE:[[:space:]]*(.*) ]]; then
            current_file="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^LINE:[[:space:]]*(.*) ]]; then
            current_line="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^SEVERITY:[[:space:]]*(.*) ]]; then
            current_severity="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^CATEGORY:[[:space:]]*(.*) ]]; then
            current_category="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^DESCRIPTION:[[:space:]]*(.*) ]]; then
            current_description="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^RECOMMENDATION:[[:space:]]*(.*) ]]; then
            current_recommendation="${BASH_REMATCH[1]}"
        elif [[ "$line" == "CODE_SNIPPET:" ]]; then
            in_code_block=true
            continue
        elif [[ "$line" == "\`\`\`" ]]; then
            if [ "$in_code_block" = true ]; then
                in_code_block=false
            fi
            continue
        elif [ "$in_code_block" = true ]; then
            current_code="${current_code}${line}\n"
        fi
    fi
done < "$RECOMMENDATIONS_FILE"

echo ""
echo "✅ Posted $comment_count individual comments to PR #$PR_ID"
