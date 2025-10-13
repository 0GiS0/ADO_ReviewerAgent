#!/bin/bash

echo "🤖 PR Analysis with GitHub Copilot CLI"
echo "======================================="

# Parameters
PR_DIRECTORY="$1"

echo "📋 Analysis configuration:"
echo "  - PR Directory: $PR_DIRECTORY"
echo ""

# Check if directory exists
if [ ! -d "$PR_DIRECTORY" ]; then
    echo "❌ ERROR: Directory $PR_DIRECTORY does not exist"
    exit 1
fi


# Create the prompt for Copilot
ANALYSIS_PROMPT="Analyze the files in this Pull Request and generate a file named 'pr-comment.md' with a professional and elegant format.

FORMAT INSTRUCTIONS:
- Use titles, subtitles, and emojis to highlight the status
- For each analyzed file, indicate if it's correct or has issues
- If there are relevant issues, include a code snippet of the problematic code with explanation
- End with a general conclusion

FORMAT EXAMPLE:

---
## 📝 Pull Request Analysis

### 📄 \`file/path/example.json\`

✅ **Status:** The file is correct, no relevant issues detected.

### 📄 \`other/file/problematic.cs\`

❌ **Issue detected:** Missing null input validation

\`\`\`csharp
public void ProcessData(string input)
{
    // ⚠️ ISSUE: Input is not validated for null
    var result = input.ToUpper(); // May throw NullReferenceException
}
\`\`\`

**Recommendation:** Add null validation before using the parameter.

---

### 📊 Summary
- Files reviewed: X
- Issues found: Y
- General recommendation: [your analysis here]

IMPORTANT: Save the result in a file named 'pr-comment.md' in the current directory."


# Execute Copilot CLI
echo "📡 Calling GitHub Copilot CLI to generate the analysis file..."

# Get model from environment or use default
MODEL="${MODEL:-claude-sonnet-4}"
echo "🤖 Using model: $MODEL"

# Execute copilot in non-interactive mode to generate the file
cd "$PR_DIRECTORY"
copilot -p "$ANALYSIS_PROMPT" --allow-all-tools --model "$MODEL"

# Verify the file was created by Copilot
cat "./pr-comment.md"

echo ""
echo "🎉 Analysis completed successfully"