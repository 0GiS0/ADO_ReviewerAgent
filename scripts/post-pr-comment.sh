#!/bin/bash

# Minimal script to post PR comment
# Usage: ./post-pr-comment.sh <COMMENT_FILE> <ORGANIZATION> <PROJECT> <REPOSITORY> <PR_ID> <PAT>

COMMENT_FILE="$1"
ORGANIZATION="$2"
PROJECT="$3"
REPOSITORY="$4"
PR_ID="$5"
PAT="$6"

PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/ /%20/g')
API_URL="https://dev.azure.com/$ORGANIZATION/$PROJECT_ENCODED/_apis/git/repositories/$REPOSITORY/pullRequests/$PR_ID/threads?api-version=7.1"

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