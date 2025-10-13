#!/bin/bash

# Script to post multiple PR comments from markdown files
# Usage: ./post-pr-comment.sh <COMMENTS_DIR> <ORGANIZATION> <PROJECT> <REPOSITORY> <PR_ID> <PAT>

COMMENTS_DIR="$1"
ORGANIZATION="$2"
PROJECT="$3"
REPOSITORY="$4"
PR_ID="$5"
PAT="$6"

# Mostrar el valor de los parámetros recibidos
echo "📋 Parámetros recibidos:"
echo "  - Comments Directory: $COMMENTS_DIR"
echo "  - Organization: $ORGANIZATION"
echo "  - Project: $PROJECT"
echo "  - Repository: $REPOSITORY"
echo "  - PR ID: $PR_ID"
echo ""

# Verify comments directory exists
if [ ! -d "$COMMENTS_DIR" ]; then
    echo "❌ ERROR: Directory $COMMENTS_DIR does not exist"
    exit 1
fi

# Get list of markdown files
COMMENT_FILES=($(find "$COMMENTS_DIR" -type f -name "*_analysis.md" | sort))

if [ ${#COMMENT_FILES[@]} -eq 0 ]; then
    echo "❌ ERROR: No analysis markdown files found in $COMMENTS_DIR"
    exit 1
fi

echo "📄 Found ${#COMMENT_FILES[@]} comment files to post"
echo ""

PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/ /%20/g')

echo "📁 Project encoded: $PROJECT_ENCODED"

API_URL="https://dev.azure.com/$ORGANIZATION/$PROJECT_ENCODED/_apis/git/repositories/$REPOSITORY/pullRequests/$PR_ID/threads?api-version=7.1"

echo "🔗 API URL: $API_URL"
echo ""

# Prepare authentication
if base64 --help 2>&1 | grep -q "wrap"; then
    PAT_BASE64=$(echo -n ":${PAT}" | base64 -w 0)
else
    PAT_BASE64=$(echo -n ":${PAT}" | base64 | tr -d '\n')
fi

# Counters
SUCCESSFUL_POSTS=0
FAILED_POSTS=0

# Post each comment file
for comment_file in "${COMMENT_FILES[@]}"; do
    filename=$(basename "$comment_file")
    
    echo "=================================================="
    echo "📤 Posting comment: $filename"
    echo "=================================================="
    
    # Read and escape comment content
    COMMENT_CONTENT=$(cat "$comment_file")
    ESCAPED_CONTENT=$(printf '%s' "$COMMENT_CONTENT" | \
        sed 's/\\/\\\\/g' | \
        sed 's/"/\\"/g' | \
        awk '{printf "%s\\n", $0}' | \
        sed 's/\\n$//')

    # Create temporary payload file
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

    echo "📊 Payload size: $(wc -c < "$PAYLOAD_FILE") bytes"

    # Post comment
    HTTP_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
      -X POST \
      -H "Authorization: Basic $PAT_BASE64" \
      -H "Content-Type: application/json" \
      -d @"$PAYLOAD_FILE" \
      "$API_URL")

    HTTP_CODE=$(echo "$HTTP_RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    
    # Clean up payload file
    rm -f "$PAYLOAD_FILE"

    echo "📡 HTTP Response Code: $HTTP_CODE"
    
    # Check if successful
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "✅ Comment posted successfully!"
        ((SUCCESSFUL_POSTS++))
    else
        echo "❌ Failed to post comment (HTTP $HTTP_CODE)"
        ((FAILED_POSTS++))
        
        # Show error details
        RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | sed 's/HTTPSTATUS:[0-9]*$//')
        if [ -n "$RESPONSE_BODY" ]; then
            echo "   Error details: $RESPONSE_BODY"
        fi
    fi
    
    echo ""
    
    # Add a small delay between posts to avoid rate limiting
    sleep 1
done

# Summary
echo "=================================================="
echo "📊 Posting Summary"
echo "=================================================="
echo "  - Total comments: ${#COMMENT_FILES[@]}"
echo "  - Successfully posted: $SUCCESSFUL_POSTS"
echo "  - Failed: $FAILED_POSTS"
echo ""

if [ $FAILED_POSTS -eq 0 ]; then
    echo "🎉 All comments posted successfully to PR #$PR_ID"
    exit 0
else
    echo "⚠️  Some comments failed to post. Check the logs above."
    exit 1
fi