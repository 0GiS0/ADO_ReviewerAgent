#!/bin/bash

# Parameterized script to get PR differences using Azure DevOps API
# Usage: ./get-pr-diff.sh <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> <OUTPUT_FILE>

echo "🌐 Get PR Differences using Azure DevOps API"
echo "=============================================="

# Verify parameters
if [ $# -ne 5 ]; then
    echo "❌ ERROR: Incorrect number of parameters"
    echo "Usage: $0 <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> <OUTPUT_FILE>"
    echo ""
    echo "Example:"
    echo "$0 'https://user@dev.azure.com/org/project/_git/repo' 'refs/heads/feature' 'refs/heads/main' 'your-pat' '/path/to/output.json'"
    exit 1
fi

# Assign parameters
SOURCE_REPO_URI="$1"
SOURCE_BRANCH="$2"
TARGET_BRANCH="$3"
PAT="$4"
OUTPUT_FILE="$5"

echo "📋 PR Information:"
echo "  - Repository URI: $SOURCE_REPO_URI"
echo "  - Source Branch: $SOURCE_BRANCH"
echo "  - Target Branch: $TARGET_BRANCH"
echo "  - Output File: $OUTPUT_FILE"
echo ""

# Extract repository information
echo "🔍 Processing repository URI..."
TEMP_URI=$(echo $SOURCE_REPO_URI | sed 's|https://[^@]*@||')
echo "Processed URI: $TEMP_URI"

# Get the organization
ORG=$(echo $TEMP_URI | awk -F'/' '{print $2}')
echo "  - ORGANIZATION: $ORG"

# Get the project (decode %20 to spaces)
PROJECT=$(echo $TEMP_URI | awk -F'/' '{print $3}' | sed 's/%20/ /g')
echo "  - PROJECT: $PROJECT"

# Get the repository
REPO=$(echo $TEMP_URI | awk -F'/' '{print $5}')
echo "  - REPOSITORY: $REPO"

# Clean refs/heads/ prefixes if they exist
SOURCE_BRANCH_CLEAN=$(echo "$SOURCE_BRANCH" | sed 's|refs/heads/||')
TARGET_BRANCH_CLEAN=$(echo "$TARGET_BRANCH" | sed 's|refs/heads/||')

echo "  - SOURCE BRANCH: $SOURCE_BRANCH_CLEAN"
echo "  - TARGET BRANCH: $TARGET_BRANCH_CLEAN"

# Encode project for URL
PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/ /%20/g')

# Build API URL
API_URL="https://dev.azure.com/$ORG/$PROJECT_ENCODED/_apis/git/repositories/$REPO/diffs/commits"
echo "  - API URL: $API_URL"

# API parameters
PARAMS="baseVersion=$TARGET_BRANCH_CLEAN&targetVersion=$SOURCE_BRANCH_CLEAN&baseVersionType=branch&targetVersionType=branch&api-version=7.2-preview.1"
FULL_URL="$API_URL?$PARAMS"
echo "  - FULL URL: $FULL_URL"

echo ""
echo "🌐 Making API call..."

# Generate Basic authentication header
echo "🔍 Debug PAT info:"
echo "  - PAT length: ${#PAT}"
echo "  - PAT first 4 chars: ${PAT:0:4}..."
echo "  - PAT last 4 chars: ...${PAT: -4}"

AUTH_HEADER=$(printf "%s:" "$PAT" | base64 -w 0)
echo "🔑 Authentication header generated (length: ${#AUTH_HEADER})"

# Make API call
echo "📡 Executing curl..."
echo "🔍 Debug curl - Headers and URL:"
echo "  - Authorization: Basic [HEADER_HIDDEN]"
echo "  - Content-Type: application/json"
echo "  - Accept: application/json"
echo "  - URL: $FULL_URL"

# Separate curl output: JSON goes to file, debug goes to separate log
curl -v \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  "$FULL_URL" \
  -o "$OUTPUT_FILE" \
  -w "HTTP_CODE: %{http_code}\nTOTAL_TIME: %{time_total}\n" \
  2> /tmp/curl_debug.log

CURL_EXIT_CODE=$?
echo "🔍 Curl finished with code: $CURL_EXIT_CODE"

if [ $CURL_EXIT_CODE -ne 0 ]; then
  echo "❌ ERROR: Curl failed with code $CURL_EXIT_CODE"
  echo "📋 Curl debug:"
  cat /tmp/curl_debug.log
  exit 1
fi

# Verify result
echo ""
echo "📄 Verifying result..."

if [ -f "$OUTPUT_FILE" ]; then
  echo "✅ Response file created: $OUTPUT_FILE"
  echo "📊 Size: $(du -h "$OUTPUT_FILE" | cut -f1)"
  
  # Debug: Show file content
  echo "🔍 Debug - Response file content:"
  if [ -s "$OUTPUT_FILE" ]; then
    echo "--- START CONTENT ---"
    cat "$OUTPUT_FILE"
    echo "--- END CONTENT ---"
  else
    echo "⚠️  EMPTY FILE (0 bytes)"
    echo "📋 Full curl debug:"
    if [ -f /tmp/curl_debug.log ]; then
      cat /tmp/curl_debug.log
    else
      echo "Curl debug log not found"
    fi
  fi
  
  # Verify valid JSON
  if command -v jq &> /dev/null; then
    if jq empty "$OUTPUT_FILE" 2>/dev/null; then
      echo "✅ Valid JSON received"
      
      # Extract statistics
      CHANGE_COUNT=$(jq '.changes | length' "$OUTPUT_FILE" 2>/dev/null || echo 'N/A')
      ADD_COUNT=$(jq '.changeCounts.Add // 0' "$OUTPUT_FILE" 2>/dev/null || echo '0')
      EDIT_COUNT=$(jq '.changeCounts.Edit // 0' "$OUTPUT_FILE" 2>/dev/null || echo '0')
      DELETE_COUNT=$(jq '.changeCounts.Delete // 0' "$OUTPUT_FILE" 2>/dev/null || echo '0')
      
      echo ""
      echo "📊 Diff Statistics:"
      echo "  - Total changes: $CHANGE_COUNT"
      echo "  - Files added: $ADD_COUNT"
      echo "  - Files edited: $EDIT_COUNT"
      echo "  - Files deleted: $DELETE_COUNT"
      
      echo ""
      echo "📁 Modified files:"
      jq -r '.changes[]?.item?.path // empty' "$OUTPUT_FILE" 2>/dev/null | head -10
      
      # Successful exit code
      exit 0
      
    else
      echo "❌ Invalid JSON - showing content:"
      cat "$OUTPUT_FILE"
      exit 1
    fi
  else
    echo "⚠️  jq not available - assuming valid response"
    echo "📋 First lines of file:"
    head -5 "$OUTPUT_FILE"
    exit 0
  fi
else
  echo "❌ Response file not created"
  exit 1
fi