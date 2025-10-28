#!/bin/bash

# Script para descargar archivos modificados de un PR usando Azure DevOps API
# Uso: ./download-pr-files.sh <DIFF_JSON_FILE> <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> [OUTPUT_DIR]

echo "📁 Downloading Modified PR Files"
echo "=================================="

# Verify parameters
if [ $# -lt 5 ] || [ $# -gt 6 ]; then
    echo "❌ ERROR: Incorrect number of parameters"
    echo "Usage: $0 <DIFF_JSON_FILE> <SOURCE_REPO_URI> <SOURCE_BRANCH> <TARGET_BRANCH> <PAT> [OUTPUT_DIR]"
    echo ""
    echo "Example:"
    echo "$0 '/path/to/diff.json' 'https://user@dev.azure.com/org/project/_git/repo' 'refs/heads/feature' 'refs/heads/main' 'your-pat' '/path/to/output'"
    exit 1
fi

# Assign parameters
DIFF_JSON_FILE="$1"
SOURCE_REPO_URI="$2"
SOURCE_BRANCH="$3"
TARGET_BRANCH="$4"
PAT="$5"
OUTPUT_DIR="${6:-./pr-files-$(date +%Y%m%d_%H%M%S)}"

echo "📋 Configuration:"
echo "  - Diff JSON file: $DIFF_JSON_FILE"
echo "  - Repository URI: $SOURCE_REPO_URI"
echo "  - Source Branch: $SOURCE_BRANCH"
echo "  - Target Branch: $TARGET_BRANCH"
echo "  - Output Directory: $OUTPUT_DIR"
echo ""

# Verify that JSON file exists
if [ ! -f "$DIFF_JSON_FILE" ]; then
    echo "❌ ERROR: File not found: $DIFF_JSON_FILE"
    exit 1
fi

# Verify that jq is available
if ! command -v jq &> /dev/null; then
    echo "❌ ERROR: jq is required to process JSON"
    echo "Install with: brew install jq (macOS) or apt-get install jq (Ubuntu)"
    exit 1
fi

# Verify that JSON is valid
if ! jq empty "$DIFF_JSON_FILE" 2>/dev/null; then
    echo "❌ ERROR: Invalid JSON in $DIFF_JSON_FILE"
    exit 1
fi

# Extract repository information
echo "🔍 Processing repository URI..."
TEMP_URI=$(echo $SOURCE_REPO_URI | sed 's|https://[^@]*@||')

# Get repository information
ORG=$(echo $TEMP_URI | awk -F'/' '{print $2}')
PROJECT=$(echo $TEMP_URI | awk -F'/' '{print $3}' | sed 's/%20/ /g')
REPO=$(echo $TEMP_URI | awk -F'/' '{print $5}')
PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/ /%20/g')

# Clean refs/heads/ prefixes if they exist
SOURCE_BRANCH_CLEAN=$(echo "$SOURCE_BRANCH" | sed 's|refs/heads/||')
TARGET_BRANCH_CLEAN=$(echo "$TARGET_BRANCH" | sed 's|refs/heads/||')

echo "  - ORGANIZATION: $ORG"
echo "  - PROJECT: $PROJECT"
echo "  - REPOSITORY: $REPO"
echo "  - SOURCE BRANCH: $SOURCE_BRANCH_CLEAN"
echo "  - TARGET BRANCH: $TARGET_BRANCH_CLEAN"
echo ""

# Create output directories
echo "📁 Creating directory structure..."
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/source"
mkdir -p "$OUTPUT_DIR/target" 
mkdir -p "$OUTPUT_DIR/metadata"

# Generate authentication header
AUTH_HEADER=$(printf "%s:" "$PAT" | base64 -w 0)

# Get list of modified files
echo "📋 Getting list of modified files..."
MODIFIED_FILES=$(jq -r '.changes[]? | select(.item.gitObjectType == "blob") | .item.path' "$DIFF_JSON_FILE")

if [ -z "$MODIFIED_FILES" ]; then
    echo "⚠️  No modified files found in diff"
    exit 0
fi

FILE_COUNT=$(echo "$MODIFIED_FILES" | wc -l | tr -d ' ')
echo "✅ Found $FILE_COUNT files to download"
echo ""

# Function to download a file from a specific branch
download_file() {
    local file_path="$1"
    local branch="$2"
    local output_subdir="$3"
    local display_name="$4"
    
    echo "📥 Downloading: $file_path ($display_name)"
    
    # Create directory for the file
    local file_dir="$OUTPUT_DIR/$output_subdir/$(dirname "$file_path")"
    mkdir -p "$file_dir"
    
    # API URL to get file content
    local api_url="https://dev.azure.com/$ORG/$PROJECT_ENCODED/_apis/git/repositories/$REPO/items"
    local params="path=$file_path&version=$branch&versionType=branch&includeContent=true&api-version=7.2-preview.1"
    local full_url="$api_url?$params"
    
    # Output file path
    local output_file="$OUTPUT_DIR/$output_subdir/$file_path"
    
    # Download the file
    curl -s \
        -H "Authorization: Basic $AUTH_HEADER" \
        -H "Accept: application/json" \
        "$full_url" \
        -o "$output_file.tmp" \
        2>/dev/null
    
    local curl_exit_code=$?
    
    if [ $curl_exit_code -eq 0 ]; then
        # Check if response is an API error (JSON with error message)
        if jq -e '.message' "$output_file.tmp" >/dev/null 2>&1; then
            local error_msg=$(jq -r '.message' "$output_file.tmp" 2>/dev/null)
            echo "  ❌ API Error: $error_msg"
            rm -f "$output_file.tmp"
            return 1
        else
            # Check if JSON contains content
            if jq -e '.content' "$output_file.tmp" >/dev/null 2>&1; then
                # Extract content from JSON and decode base64
                jq -r '.content' "$output_file.tmp" | base64 -d > "$output_file" 2>/dev/null
                if [ $? -eq 0 ] && [ -s "$output_file" ]; then
                    local file_size=$(du -h "$output_file" | cut -f1)
                    echo "  ✅ Downloaded ($file_size)"
                    rm -f "$output_file.tmp"
                    return 0
                else
                    # If base64 fails, save content as plain text
                    jq -r '.content // empty' "$output_file.tmp" > "$output_file"
                    local file_size=$(du -h "$output_file" | cut -f1)
                    echo "  ✅ Downloaded as text ($file_size)"
                    rm -f "$output_file.tmp"
                    return 0
                fi
            else
                # If no content field, save full response
                mv "$output_file.tmp" "$output_file"
                local file_size=$(du -h "$output_file" | cut -f1)
                echo "  ⚠️  Downloaded (metadata) ($file_size)"
                return 0
            fi
        fi
    else
        echo "  ❌ Download error (curl code: $curl_exit_code)"
        rm -f "$output_file.tmp"
        return 1
    fi
}

# Counters
SUCCESSFUL_DOWNLOADS=0
FAILED_DOWNLOADS=0
NEW_FILES=0

# Process each modified file
echo "🔄 Processing files..."
while IFS= read -r file_path; do
    if [ -n "$file_path" ]; then
        echo ""
        echo "📄 Processing: $file_path"
        
        # Download version from source branch
        if download_file "$file_path" "$SOURCE_BRANCH_CLEAN" "source" "source branch"; then
            ((SUCCESSFUL_DOWNLOADS++))
        else
            ((FAILED_DOWNLOADS++))
        fi
        
        # Download version from target branch (may fail if new file)
        if download_file "$file_path" "$TARGET_BRANCH_CLEAN" "target" "target branch"; then
            ((SUCCESSFUL_DOWNLOADS++))
        else
            echo "  ⚠️  Could not download from target branch (possibly new file)"
            ((NEW_FILES++))
        fi
    fi
done <<< "$MODIFIED_FILES"

# Create metadata file
echo ""
echo "📝 Generating metadata..."
METADATA_FILE="$OUTPUT_DIR/metadata/pr-info.json"

cat > "$METADATA_FILE" << EOF
{
  "download_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "repository": {
    "organization": "$ORG",
    "project": "$PROJECT",
    "repository": "$REPO",
    "uri": "$SOURCE_REPO_URI"
  },
  "branches": {
    "source": "$SOURCE_BRANCH_CLEAN",
    "target": "$TARGET_BRANCH_CLEAN"
  },
  "statistics": {
    "total_files": $FILE_COUNT,
    "successful_downloads": $SUCCESSFUL_DOWNLOADS,
    "failed_downloads": $FAILED_DOWNLOADS,
    "new_files_not_in_target": $NEW_FILES
  },
  "diff_file": "$DIFF_JSON_FILE"
}
EOF

# Copy original diff file to metadata
cp "$DIFF_JSON_FILE" "$OUTPUT_DIR/metadata/original-diff.json"

echo ""
echo "📊 Download Summary:"
echo "  - Total files: $FILE_COUNT"
echo "  - Successful downloads: $SUCCESSFUL_DOWNLOADS"
echo "  - Failed downloads: $FAILED_DOWNLOADS"
echo "  - New files (not in target): $NEW_FILES"
echo "  - Output directory: $OUTPUT_DIR"
echo ""
echo "📁 Directory structure created:"
echo "  $OUTPUT_DIR/"
echo "  ├── source/         # Files from source branch"
echo "  ├── target/         # Files from target branch"  
echo "  └── metadata/       # PR info and original diff"
echo "      ├── pr-info.json"
echo "      └── original-diff.json"
echo ""

if [ $FAILED_DOWNLOADS -gt 0 ]; then
    echo "❌ Some downloads failed. Check logs above for details."
    exit 1
else
    echo "✅ All files downloaded successfully"
    if [ $NEW_FILES -gt 0 ]; then
        echo "ℹ️  ($NEW_FILES new files not found in target branch)"
    fi
    exit 0
fi