#!/bin/bash

# Minimal script to post PR comment
# Usage: ./post-pr-comment.sh <COMMENT_FILE> <ORGANIZATION> <PROJECT> <REPOSITORY> <PR_ID> <PAT>

COMMENT_FILE="$1"
ORGANIZATION="$2"
PROJECT="$3"
REPOSITORY="$4"
PR_ID="$5"
PAT="$6"

# Mostrar el valor de los parámetros recibidos
echo "📋 Parámetros recibidos:"
echo "  - Comment File: $COMMENT_FILE"
echo "  - Organization: $ORGANIZATION"
echo "  - Project: $PROJECT"
echo "  - Repository: $REPOSITORY"
echo "  - PR ID: $PR_ID"
echo "  - PAT: $PAT"

PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/ /%20/g')

echo "📁 Project encoded: $PROJECT_ENCODED"

API_URL="https://dev.azure.com/$ORGANIZATION/$PROJECT_ENCODED/_apis/git/repositories/$REPOSITORY/pullRequests/$PR_ID/threads?api-version=7.1"

echo "🔗 API URL: $API_URL"

COMMENT_CONTENT=$(cat "$COMMENT_FILE")
ESCAPED_CONTENT=$(printf '%s' "$COMMENT_CONTENT" | \
    sed 's/\\/\\\\/g' | \
    sed 's/"/\\"/g' | \
    awk '{printf "%s\\n", $0}' | \
    sed 's/\\n$//')

PAYLOAD_FILE="/tmp/pr-comment-payload-$$.json"
cat > "$PAYLOAD_FILE" << EOF
{
  "comments": [
    {
      "parentCommentId": 0,
      "content": "$ESCAPED_CONTENT",
      "commentType": 1
    }
  ],
  "status": 1
}
EOF

echo "Contenido del payload:"
cat "$PAYLOAD_FILE"
echo "📊 Payload size: $(wc -c < "$PAYLOAD_FILE") bytes"


if base64 --help 2>&1 | grep -q "wrap"; then
    PAT_BASE64=$(echo -n ":${PAT}" | base64 -w 0)
else
    PAT_BASE64=$(echo -n ":${PAT}" | base64 | tr -d '\n')
fi

HTTP_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
  -X POST \
  -H "Authorization: Basic $PAT_BASE64" \
  -H "Content-Type: application/json" \
  -d @"$PAYLOAD_FILE" \
  "$API_URL")

HTTP_CODE=$(echo "$HTTP_RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)


echo "📡 HTTP Response Code: $HTTP_CODE"
echo ""
echo "🎉 Comentario de revisión publicado exitosamente en la PR #$PR_ID"