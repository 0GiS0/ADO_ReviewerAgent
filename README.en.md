# 🤖 Azure DevOps Reviewer Agent

<div align="center">

[![YouTube Channel Subscribers](https://img.shields.io/youtube/channel/subscribers/UC140iBrEZbOtvxWsJ-Tb0lQ?style=for-the-badge&logo=youtube&logoColor=white&color=red)](https://www.youtube.com/c/GiselaTorres?sub_confirmation=1)
[![GitHub followers](https://img.shields.io/github/followers/0GiS0?style=for-the-badge&logo=github&logoColor=white)](https://github.com/0GiS0)
[![LinkedIn Follow](https://img.shields.io/badge/LinkedIn-Follow-blue?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/giselatorresbuitrago/)
[![X Follow](https://img.shields.io/badge/X-Follow-black?style=for-the-badge&logo=x&logoColor=white)](https://twitter.com/0GiS0)

**🌍 Languages:** [🇪🇸 Español](README.md) | 🇬🇧 **English** | [🇫🇷 Français](README.fr.md)

</div>

Hello developer 👋🏻! This repository implements a workflow in Azure Pipelines 🚀 that integrates **GitHub Copilot CLI** 🤖 to automatically review Pull Requests and identify potential issues in the code. The code was used for my video: [🚀 Take Azure DevOps to the next level with GitHub Copilot CLI 🤖](https://youtu.be/ZS0LQA2_zZQ)

<a href="https://youtu.be/ZS0LQA2_zZQ">
 <img src="https://img.youtube.com/vi/ZS0LQA2_zZQ/maxresdefault.jpg" alt="🚀 Take Azure DevOps to the next level with GitHub Copilot CLI 🤖" width="100%" />
</a>

### 🎯 Objectives

- ✅ Automate code review using AI (GitHub Copilot)
- ✅ Integrate GitHub Copilot CLI with Azure DevOps
- ✅ Automatically analyze Pull Requests on every change
- ✅ Identify potential security, performance, and quality issues
- ✅ Publish automatic review comments on PRs

## 🚀 What Does It Do?

The pipeline is automatically triggered when a Pull Request is created or updated and performs the following workflow:

1. 📋 **Gets PR differences** - Downloads changes using Azure DevOps API
2. 📁 **Downloads modified files** - Organizes files by branch (source and target)
3. 🤖 **Runs GitHub Copilot CLI** - Analyzes code with AI to identify issues
4. 💬 **Posts comments** - Creates automatic comments on the PR with findings
5. 📦 **Generates artifacts** - Saves complete analysis for reference

## 👀 Technologies Used

- **Azure DevOps** - Pull Request and pipeline management
- **GitHub Copilot CLI** - Automatic code analysis with AI
- **Bash Scripts** - Automation and orchestration
- **Node.js 22.x** - Runtime for Copilot CLI
- **Azure Pipelines YAML** - Workflow definition

## 📦 Project Structure

```
├── azure-pipelines.yml              # Pipeline definition
├── templates/
│   └── run-script.yml              # Reusable template for running scripts
├── scripts/                         # Automation scripts
│   ├── get-pr-diff.sh              # Gets PR differences
│   ├── download-pr-files.sh        # Downloads modified files
│   ├── analyze-with-copilot.sh     # Analyzes with GitHub Copilot
│   ├── post-pr-comment.sh          # Posts comments on PR
│   ├── get-and-download-pr-files.sh # Wrapper: diff + download
│   ├── complete-pr-analysis.sh     # Complete flow: diff + download + analysis
│   └── example-usage.sh            # Usage examples
└── README.md                        # This file
```

## ⚙️ Required Configuration

### Environment Variables

- `AZURE_DEVOPS_EXT_PAT` - Azure DevOps Personal Access Token with Code permissions (Read/Write)
- `MODEL` - Language model to use (e.g., claude-sonnet-4)
- `COPILOT_VERSION` - Copilot CLI version to install (e.g., latest or specific version)

## 📝 How the Pipeline Works - Step by Step

The pipeline automatically executes the following steps when a PR is created or updated:

### 🔧 Step 1: Show PR Information

**Command:** `📋 Show PR Information`

Prints debug information in the logs:
- Repository URI (repository URL)
- PR # (pull request number)
- Source Branch (branch with changes)
- Target Branch (merge target branch)
- Source Commit (current commit)
- Build Repository and Commit
- Working directories (Analysis Dir, Diff File)

### ⚙️ Step 2: Setup Node.js 22.x

**Command:** `⚙️ Setup Node.js 22.x`

- Installs Node.js version 22.x on the build agent
- Necessary because Copilot CLI is a Node tool

### 🔍 Step 3: Detect NPM Global Path

**Command:** `🔍 Detect NPM Global Path`

```bash
NPM_PREFIX=$(npm config get prefix)
```

- Gets the path where npm installs global packages (e.g., `/usr/local/lib/node_modules`)
- Saves that path in the `NPM_GLOBAL_PATH` variable to use in cache

### 📦 Step 4: Cache NPM Packages

**Command:** `📦 Cache Global NPM Packages`

- **Cache key:** `npm-global | OS | copilot | COPILOT_VERSION`
- **Cached path:** The global NPM path from the previous step
- **Benefit:** Subsequent builds use the cache without re-downloading @github/copilot (saves 30-60 seconds)

### 📦 Step 5: Install Copilot CLI

**Command:** `📦 Install Copilot CLI`

```bash
if ! command -v copilot &> /dev/null; then
  npm install -g @github/copilot@$(COPILOT_VERSION)
else
  echo "✅ @github/copilot already installed (from cache)"
fi
```

- Checks if copilot is already installed (from cache)
- If not, installs it: `npm install -g @github/copilot@latest`
- If it's in cache, skips the download

### 🔍 Step 6: Get PR Differences

**Command:** `🔍 Get PR Differences`

**Runs:** `scripts/get-pr-diff.sh` with:
```bash
./scripts/get-pr-diff.sh \
  "$(System.PullRequest.SourceRepositoryUri)" \
  "$(System.PullRequest.SourceBranch)" \
  "$(System.PullRequest.TargetBranch)" \
  "$(AZURE_DEVOPS_EXT_PAT)" \
  "$(DIFF_FILE)"
```

**What it does:**
- Calls Azure DevOps REST API
- Gets all differences between branches (added, modified, deleted files)
- Saves result in JSON: `$(Build.ArtifactStagingDirectory)/pr-diff.json`

### 📁 Step 7: Download Modified Files

**Command:** `📁 Download Modified Files`

**Runs:** `scripts/download-pr-files.sh` with:
```bash
./scripts/download-pr-files.sh \
  "$(DIFF_FILE)" \
  "$(System.PullRequest.SourceRepositoryUri)" \
  "$(System.PullRequest.SourceBranch)" \
  "$(System.PullRequest.TargetBranch)" \
  "$(AZURE_DEVOPS_EXT_PAT)" \
  "$(ANALYSIS_DIR)"
```

**What it does:**
- Reads the diff JSON file (previous step)
- Downloads files into 2 organized directories:
  - `$(ANALYSIS_DIR)/source/` - Files from source branch (with changes)
  - `$(ANALYSIS_DIR)/target/` - Files from target branch (without changes)
- Maintains original folder structure

### 🤖 Step 8: Analyze with GitHub Copilot CLI

**Command:** `🤖 Analyze with GitHub Copilot CLI`

**Runs:** `scripts/analyze-with-copilot.sh` with:
```bash
./scripts/analyze-with-copilot.sh "$(ANALYSIS_DIR)/source"
```

**What it does:**
- Runs copilot CLI with `claude-sonnet-4` model (configurable)
- Analyzes downloaded files looking for issues:
  - 🔒 **Security** - Vulnerabilities, unauthorized access, validation
  - ⚡ **Performance** - Inefficient loops, costly operations
  - 🧹 **Clean Code** - Refactoring, variable names, duplication
  - 📝 **TypeScript** - Typing, interfaces, generic types
  - 🐛 **Bugs** - Logic errors, null checks, edge cases
- Generates Markdown comments: `$(ANALYSIS_DIR)/source/pr-comments/`

### 📋 Step 9: Extract PR Info

**Command:** `📋 Extract PR Info`

**What it does:**
```bash
REPO_URI="$(System.PullRequest.SourceRepositoryUri)"
# Extracts: https://dev.azure.com/returngisorg/GitHub%20Copilot%20CLI/_git/ReviewerAgent
ORG="returngisorg"              # Organization
PROJECT="GitHub Copilot CLI"    # Project
REPO="ReviewerAgent"            # Repository
PR_ID="123"                     # PR ID
```

- Parses the repository URL
- Extracts components needed for Azure DevOps API
- Saves in variables: `PR_ORG`, `PR_PROJECT`, `PR_REPO`, `PR_NUM`

### 💬 Step 10: Publish Comment on PR

**Command:** `💬 Publish Comment on PR`

**Runs:** `scripts/post-pr-comment.sh` with:
```bash
./scripts/post-pr-comment.sh \
  "$(ANALYSIS_DIR)/source/pr-comments" \
  "$(PR_ORG)" \
  "$(PR_PROJECT)" \
  "$(PR_REPO)" \
  "$(PR_NUM)" \
  "$(AZURE_DEVOPS_EXT_PAT)"
```

**What it does:**
- Reads comments generated by Copilot (step 8)
- Connects to Azure DevOps API using PAT
- Posts comments directly on the PR
- **Result:** Developers see in the PR exactly what issues Copilot found

### 📦 Step 11: Publish Artifacts

**Command:** `📦 Publish Complete Analysis as Artifact`

**What it does:**
- Publishes the entire `$(Build.ArtifactStagingDirectory)` folder as an artifact
- Artifact name: `pr-analysis-complete`
- **Downloadable content:**
  - `pr-diff.json` - Complete differences in JSON format
  - `pr-analysis/source/` - All analyzed files
  - `pr-analysis/source/pr-comments/` - Generated comments
  - Complete execution logs

**Benefit:** Users can download and review the complete analysis from Azure Pipelines

## 📝 How the Pipeline Works - Step by Step

The pipeline automatically executes the following steps when a PR is created or updated:

### 🔧 Environment Preparation
1. **📋 Show PR Information** - Prints PR data (repository, branch, commit)
2. **⚙️ Setup Node.js 22.x** - Installs Node.js for Copilot CLI
3. **🔍 Detect NPM Path** - Locates global NPM path
4. **📦 Cache NPM Packages** - Caches global packages to speed up future runs
5. **📦 Install Copilot CLI** - Installs @github/copilot in specified version

### 📊 PR Analysis
6. **🔍 Get PR Differences** - Extracts changes using Azure DevOps API
7. **📁 Download Modified Files** - Downloads files from both branches (source and target)
8. **🤖 Analyze with GitHub Copilot** - Runs Copilot to review the code
9. **📋 Extract PR Info** - Gets data like organization, project, repository, and PR ID

### 📤 Results Publication
10. **💬 Publish Comment on PR** - Posts findings as a comment on the PR
11. **📦 Publish Artifacts** - Saves complete analysis as build artifact

## 🔄 Complete Workflow

```
Pull Request Created/Updated
         ↓
   Show PR Information
         ↓
    Setup Node.js 22.x
         ↓
  Detect NPM Global Path
         ↓
 Cache Global NPM Packages
         ↓
 Install Copilot CLI
         ↓
  Get PR Differences
    (Azure DevOps API)
         ↓
 Download Modified Files
         ↓
Analyze with Copilot
  (Identifies issues)
         ↓
Extract PR Info
   (Org, Project, Repo, PR ID)
         ↓
Publish Comment on PR
         ↓
   Publish Artifacts
         ↓
   ✅ Review Complete
```

## 🚀 Installation

### Prerequisites

1. **Azure DevOps** with permissions to:
   - Create pipelines
   - Configure pipeline variables
   - Access Pull Requests

2. **GitHub Account** with:
   - Access to GitHub Copilot
   - Personal Access Token with Copilot permissions

3. **Build Agent** with:
   - Node.js 18.x or higher
   - Git
   - Bash

### Configuration

#### 1. Create a Variable Group

Create a **Variable Group** named `GitHub Copilot CLI` with the following variables:

**Required Variables:**
- `AZURE_DEVOPS_EXT_PAT`: Azure DevOps Personal Access Token with permissions for:
  - **Code (Read)**: To read PR information and modified files
  - **Pull Request (Contribute)**: To create comments on PRs

**Instructions to create Azure DevOps PAT:**
1. Go to your user profile in Azure DevOps (top right corner)
2. Select "Personal access tokens"
3. Click "New Token"
4. Configure:
   - Name: "ReviewerAgent Pipeline"
   - Organization: Your organization
   - Expiration: According to your security policies
   - Scopes: Select "Code" (Read) and "Pull Request" (Contribute)
5. Copy the generated token and save it as `AZURE_DEVOPS_EXT_PAT` in the Variable Group

**Important:** Mark the variable as "Secret" to protect the token

#### 2. Configure the Pipeline

1. In your Azure DevOps project, go to **Pipelines** → **New Pipeline**
2. Select your repository
3. Choose "Existing Azure Pipelines YAML file"
4. Select the `azure-pipelines.yml` file
5. Save the pipeline

#### 3. Configure Model and Version (Optional)

In the `azure-pipelines.yml` file, you can configure:

```yaml
variables:
  - group: "GitHub Copilot CLI"
  - name: MODEL
    value: claude-sonnet-4  # Change the model according to your preference
  - name: COPILOT_VERSION
    value: "latest"         # or specify a fixed version like "0.0.339"
```

**Available models:**
- `claude-sonnet-4` (recommended)
- `gpt-4o`
- `o1-preview`
- `o1-mini`

## 📁 Included Scripts

### 1. `get-pr-diff.sh`
Gets the differences of a Pull Request using the Azure DevOps API.

**Parameters:**
- `SOURCE_REPO_URI`: Repository URI
- `SOURCE_BRANCH`: Source branch
- `TARGET_BRANCH`: Target branch
- `PAT`: Personal Access Token
- `OUTPUT_FILE`: Output file

**Usage:**
```bash
./scripts/get-pr-diff.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/output.json'
```

### 2. `download-pr-files.sh`
Downloads modified files in a PR, organizing them into temporary directories by branch.

**Parameters:**
- `DIFF_FILE`: Diff JSON file
- `SOURCE_REPO_URI`: Repository URI
- `SOURCE_BRANCH`: Source branch
- `TARGET_BRANCH`: Target branch
- `PAT`: Personal Access Token
- `OUTPUT_DIR`: Output directory

**Usage:**
```bash
./scripts/download-pr-files.sh \
  '/path/to/diff.json' \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/output-dir'
```

### 3. `analyze-with-copilot.sh`
Analyzes files using GitHub Copilot CLI and generates a PR review comment.

**Parameters:**
- `SOURCE_DIR`: Directory with downloaded files

**Usage:**
```bash
./scripts/analyze-with-copilot.sh '/path/to/downloaded/files'
```

### 4. `post-pr-comment.sh`
Posts review comments on Azure DevOps Pull Requests.

**Parameters:**
- `COMMENT_DIR`: Directory with comments to post
- `ORG`: Azure DevOps organization
- `PROJECT`: Azure DevOps project
- `REPO`: Repository
- `PR_ID`: Pull Request ID
- `PAT`: Personal Access Token

**Usage:**
```bash
./scripts/post-pr-comment.sh \
  '/path/to/comments' \
  'your-org' \
  'your-project' \
  'your-repo' \
  '123' \
  'your-pat-token'
```

### 5. `get-and-download-pr-files.sh` (Wrapper)
Complete script that combines getting the diff and downloading files.

**Usage:**
```bash
./scripts/get-and-download-pr-files.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/output-dir'
```

### 6. `complete-pr-analysis.sh` (Complete flow)
Script that executes the entire flow: get diff, download files, and analyze with Copilot.

**Usage:**
```bash
./scripts/complete-pr-analysis.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/analysis-dir'
```

### 7. `example-usage.sh`
Demonstration script showing how to use all components.

## 🏗️ Architecture

### Reusable Templates

The project uses Azure DevOps templates to improve maintainability:

**`templates/run-script.yml`**: Generic template for running bash scripts
- Simplifies script invocation
- Handles errors automatically
- Propagates necessary environment variables
- Allows customization of working directory

**Template usage:**
```yaml
- template: templates/run-script.yml
  parameters:
    script: my-script.sh
    args: '"arg1" "arg2"'
    displayName: 🔧 My Step
    workingDirectory: $(Build.SourcesDirectory)
```

### NPM Cache

The pipeline implements global NPM package caching to optimize times:
- Automatically detects global NPM path
- Caches `@github/copilot` installations
- Reduces installation time in subsequent builds
