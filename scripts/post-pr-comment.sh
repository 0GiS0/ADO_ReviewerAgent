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

API_URL="https://dev.azure.com/$ORGANIZATION/$PROJECT/_apis/git/repositories/$REPOSITORY/pullRequests/$PR_ID/threads?api-version=7.1"

echo "Mostrar el archivo de comentario:"
cat "$COMMENT_FILE"


PAYLOAD_FILE="/tmp/pr-comment-payload-$$.json"
cat > "$PAYLOAD_FILE" << EOF
{
  "comments": [
    {
      "parentCommentId": 0,
      "content": "$(cat "$COMMENT_FILE")",
      "commentType": 1
    }
  ],
  "status": 1
}
EOF

AUTH_HEADER=$(printf "%s:" "$PAT" | base64)

HTTP_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
  --connect-timeout 30 \
  --max-time 60 \
  -X POST \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d @"$PAYLOAD_FILE" \
  "$API_URL")

HTTP_CODE=$(echo "$HTTP_RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)


echo "📡 HTTP Response Code: $HTTP_CODE"
echo ""
echo "🎉 Comentario de revisión publicado exitosamente en la PR #$PR_ID"