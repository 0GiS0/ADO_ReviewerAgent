# 🤖 Azure DevOps Reviewer Agent

<div align="center">

[![YouTube Channel Subscribers](https://img.shields.io/youtube/channel/subscribers/UC140iBrEZbOtvxWsJ-Tb0lQ?style=for-the-badge&logo=youtube&logoColor=white&color=red)](https://www.youtube.com/c/GiselaTorres?sub_confirmation=1)
[![GitHub followers](https://img.shields.io/github/followers/0GiS0?style=for-the-badge&logo=github&logoColor=white)](https://github.com/0GiS0)
[![LinkedIn Follow](https://img.shields.io/badge/LinkedIn-Suivez-blue?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/giselatorresbuitrago/)
[![X Follow](https://img.shields.io/badge/X-Suivez-black?style=for-the-badge&logo=x&logoColor=white)](https://twitter.com/0GiS0)

**🌍 Langues:** [🇪🇸 Español](README.md) | [🇬🇧 English](README.en.md) | 🇫🇷 **Français**

</div>

Bonjour développeur 👋🏻! Ce dépôt implémente un workflow dans Azure Pipelines 🚀 qui intègre **GitHub Copilot CLI** 🤖 pour réviser automatiquement les Pull Requests et identifier les problèmes potentiels dans le code. Le code a été utilisé pour ma vidéo : [🚀 Amenez Azure DevOps au niveau supérieur avec GitHub Copilot CLI 🤖](https://youtu.be/ZS0LQA2_zZQ)

<a href="https://youtu.be/ZS0LQA2_zZQ">
 <img src="https://img.youtube.com/vi/ZS0LQA2_zZQ/maxresdefault.jpg" alt="🚀 Amenez Azure DevOps au niveau supérieur avec GitHub Copilot CLI 🤖" width="100%" />
</a>

### 🎯 Objectifs

- ✅ Automatiser la révision de code à l'aide de l'IA (GitHub Copilot)
- ✅ Intégrer GitHub Copilot CLI avec Azure DevOps
- ✅ Analyser automatiquement les Pull Requests à chaque changement
- ✅ Identifier les problèmes potentiels de sécurité, performance et qualité
- ✅ Publier des commentaires de révision automatiques sur les PRs

## 🚀 Que Fait-Il ?

Le pipeline est automatiquement déclenché lorsqu'une Pull Request est créée ou mise à jour et effectue le workflow suivant :

1. 📋 **Obtient les différences de la PR** - Télécharge les changements en utilisant l'API Azure DevOps
2. 📁 **Télécharge les fichiers modifiés** - Organise les fichiers par branche (source et cible)
3. 🤖 **Exécute GitHub Copilot CLI** - Analyse le code avec l'IA pour identifier les problèmes
4. 💬 **Publie des commentaires** - Crée des commentaires automatiques sur la PR avec les résultats
5. 📦 **Génère des artefacts** - Sauvegarde l'analyse complète pour référence

## 👀 Technologies Utilisées

- **Azure DevOps** - Gestion des Pull Requests et des pipelines
- **GitHub Copilot CLI** - Analyse automatique de code avec IA
- **Scripts Bash** - Automatisation et orchestration
- **Node.js 22.x** - Runtime pour Copilot CLI
- **Azure Pipelines YAML** - Définition du workflow

## 📦 Structure du Projet

```
├── azure-pipelines.yml              # Définition du pipeline
├── templates/
│   └── run-script.yml              # Template réutilisable pour exécuter des scripts
├── scripts/                         # Scripts d'automatisation
│   ├── get-pr-diff.sh              # Obtient les différences de la PR
│   ├── download-pr-files.sh        # Télécharge les fichiers modifiés
│   ├── analyze-with-copilot.sh     # Analyse avec GitHub Copilot
│   ├── post-pr-comment.sh          # Publie des commentaires sur la PR
│   ├── get-and-download-pr-files.sh # Wrapper : diff + téléchargement
│   ├── complete-pr-analysis.sh     # Flux complet : diff + téléchargement + analyse
│   └── example-usage.sh            # Exemples d'utilisation
└── README.md                        # Ce fichier
```

## ⚙️ Configuration Requise

### Variables d'Environnement

- `AZURE_DEVOPS_EXT_PAT` - Personal Access Token Azure DevOps avec permissions Code (Lecture/Écriture)
- `MODEL` - Modèle de langage à utiliser (ex. claude-sonnet-4)
- `COPILOT_VERSION` - Version de Copilot CLI à installer (ex. latest ou version spécifique)

## 📝 Comment le Pipeline Fonctionne - Étape par Étape

Le pipeline exécute automatiquement les étapes suivantes lorsqu'une PR est créée ou mise à jour :

### 🔧 Étape 1 : Afficher les Informations de la PR

**Commande:** `📋 Show PR Information`

Affiche les informations de débogage dans les logs :
- Repository URI (URL du dépôt)
- PR # (numéro de la pull request)
- Source Branch (branche avec les changements)
- Target Branch (branche cible du merge)
- Source Commit (commit actuel)
- Build Repository et Commit
- Répertoires de travail (Analysis Dir, Diff File)

### ⚙️ Étape 2 : Configuration de Node.js 22.x

**Commande:** `⚙️ Setup Node.js 22.x`

- Installe Node.js version 22.x sur l'agent de build
- Nécessaire car Copilot CLI est un outil Node

### 🔍 Étape 3 : Détecter le Chemin NPM Global

**Commande:** `🔍 Detect NPM Global Path`

```bash
NPM_PREFIX=$(npm config get prefix)
```

- Obtient le chemin où npm installe les paquets globaux (ex. `/usr/local/lib/node_modules`)
- Sauvegarde ce chemin dans la variable `NPM_GLOBAL_PATH` pour l'utiliser dans le cache

### 📦 Étape 4 : Mettre en Cache les Paquets NPM

**Commande:** `📦 Cache Global NPM Packages`

- **Clé de cache:** `npm-global | OS | copilot | COPILOT_VERSION`
- **Chemin mis en cache:** Le chemin NPM global de l'étape précédente
- **Avantage:** Les builds ultérieurs utilisent le cache sans re-télécharger @github/copilot (économise 30-60 secondes)

### 📦 Étape 5 : Installer Copilot CLI

**Commande:** `📦 Install Copilot CLI`

```bash
if ! command -v copilot &> /dev/null; then
  npm install -g @github/copilot@$(COPILOT_VERSION)
else
  echo "✅ @github/copilot already installed (from cache)"
fi
```

- Vérifie si copilot est déjà installé (depuis le cache)
- Sinon, l'installe : `npm install -g @github/copilot@latest`
- S'il est dans le cache, ignore le téléchargement

### 🔍 Étape 6 : Obtenir les Différences de la PR

**Commande:** `🔍 Get PR Differences`

**Exécute:** `scripts/get-pr-diff.sh` avec :
```bash
./scripts/get-pr-diff.sh \
  "$(System.PullRequest.SourceRepositoryUri)" \
  "$(System.PullRequest.SourceBranch)" \
  "$(System.PullRequest.TargetBranch)" \
  "$(AZURE_DEVOPS_EXT_PAT)" \
  "$(DIFF_FILE)"
```

**Ce qu'il fait:**
- Appelle l'API REST Azure DevOps
- Obtient toutes les différences entre les branches (fichiers ajoutés, modifiés, supprimés)
- Sauvegarde le résultat en JSON : `$(Build.ArtifactStagingDirectory)/pr-diff.json`

### 📁 Étape 7 : Télécharger les Fichiers Modifiés

**Commande:** `📁 Download Modified Files`

**Exécute:** `scripts/download-pr-files.sh` avec :
```bash
./scripts/download-pr-files.sh \
  "$(DIFF_FILE)" \
  "$(System.PullRequest.SourceRepositoryUri)" \
  "$(System.PullRequest.SourceBranch)" \
  "$(System.PullRequest.TargetBranch)" \
  "$(AZURE_DEVOPS_EXT_PAT)" \
  "$(ANALYSIS_DIR)"
```

**Ce qu'il fait:**
- Lit le fichier JSON de diff (étape précédente)
- Télécharge les fichiers dans 2 répertoires organisés :
  - `$(ANALYSIS_DIR)/source/` - Fichiers de la branche source (avec changements)
  - `$(ANALYSIS_DIR)/target/` - Fichiers de la branche cible (sans changements)
- Maintient la structure de dossiers originale

### 🤖 Étape 8 : Analyser avec GitHub Copilot CLI

**Commande:** `🤖 Analyze with GitHub Copilot CLI`

**Exécute:** `scripts/analyze-with-copilot.sh` avec :
```bash
./scripts/analyze-with-copilot.sh "$(ANALYSIS_DIR)/source"
```

**Ce qu'il fait:**
- Exécute copilot CLI avec le modèle `claude-sonnet-4` (configurable)
- Analyse les fichiers téléchargés à la recherche de problèmes :
  - 🔒 **Sécurité** - Vulnérabilités, accès non autorisés, validation
  - ⚡ **Performance** - Boucles inefficaces, opérations coûteuses
  - 🧹 **Code Propre** - Refactoring, noms de variables, duplication
  - 📝 **TypeScript** - Typage, interfaces, types génériques
  - 🐛 **Bugs** - Erreurs de logique, vérifications null, cas limites
- Génère des commentaires Markdown : `$(ANALYSIS_DIR)/source/pr-comments/`

### 📋 Étape 9 : Extraire les Informations de la PR

**Commande:** `📋 Extract PR Info`

**Ce qu'il fait:**
```bash
REPO_URI="$(System.PullRequest.SourceRepositoryUri)"
# Extrait : https://dev.azure.com/returngisorg/GitHub%20Copilot%20CLI/_git/ReviewerAgent
ORG="returngisorg"              # Organisation
PROJECT="GitHub Copilot CLI"    # Projet
REPO="ReviewerAgent"            # Dépôt
PR_ID="123"                     # ID de la PR
```

- Parse l'URL du dépôt
- Extrait les composants nécessaires pour l'API Azure DevOps
- Sauvegarde dans les variables : `PR_ORG`, `PR_PROJECT`, `PR_REPO`, `PR_NUM`

### 💬 Étape 10 : Publier un Commentaire sur la PR

**Commande:** `💬 Publish Comment on PR`

**Exécute:** `scripts/post-pr-comment.sh` avec :
```bash
./scripts/post-pr-comment.sh \
  "$(ANALYSIS_DIR)/source/pr-comments" \
  "$(PR_ORG)" \
  "$(PR_PROJECT)" \
  "$(PR_REPO)" \
  "$(PR_NUM)" \
  "$(AZURE_DEVOPS_EXT_PAT)"
```

**Ce qu'il fait:**
- Lit les commentaires générés par Copilot (étape 8)
- Se connecte à l'API Azure DevOps en utilisant le PAT
- Publie les commentaires directement sur la PR
- **Résultat:** Les développeurs voient dans la PR exactement quels problèmes Copilot a trouvés

### 📦 Étape 11 : Publier les Artefacts

**Commande:** `📦 Publish Complete Analysis as Artifact`

**Ce qu'il fait:**
- Publie l'ensemble du dossier `$(Build.ArtifactStagingDirectory)` comme artefact
- Nom de l'artefact : `pr-analysis-complete`
- **Contenu téléchargeable:**
  - `pr-diff.json` - Différences complètes au format JSON
  - `pr-analysis/source/` - Tous les fichiers analysés
  - `pr-analysis/source/pr-comments/` - Commentaires générés
  - Logs d'exécution complets

**Avantage:** Les utilisateurs peuvent télécharger et examiner l'analyse complète depuis Azure Pipelines

## 📝 Comment le Pipeline Fonctionne - Étape par Étape

Le pipeline exécute automatiquement les étapes suivantes lorsqu'une PR est créée ou mise à jour :

### 🔧 Préparation de l'Environnement
1. **📋 Afficher les Informations de la PR** - Affiche les données de la PR (dépôt, branche, commit)
2. **⚙️ Configuration de Node.js 22.x** - Installe Node.js pour Copilot CLI
3. **🔍 Détecter le Chemin NPM** - Localise le chemin NPM global
4. **📦 Cache des Paquets NPM** - Met en cache les paquets globaux pour accélérer les exécutions futures
5. **📦 Installer Copilot CLI** - Installe @github/copilot dans la version spécifiée

### 📊 Analyse de la PR
6. **🔍 Obtenir les Différences de la PR** - Extrait les changements en utilisant l'API Azure DevOps
7. **📁 Télécharger les Fichiers Modifiés** - Télécharge les fichiers des deux branches (source et cible)
8. **🤖 Analyser avec GitHub Copilot** - Exécute Copilot pour réviser le code
9. **📋 Extraire les Informations de la PR** - Obtient les données comme l'organisation, le projet, le dépôt et l'ID de la PR

### 📤 Publication des Résultats
10. **💬 Publier un Commentaire sur la PR** - Publie les résultats comme commentaire sur la PR
11. **📦 Publier les Artefacts** - Sauvegarde l'analyse complète comme artefact de build

## 🔄 Workflow Complet

```
Pull Request Créée/Mise à jour
         ↓
   Afficher les Informations de la PR
         ↓
    Configuration de Node.js 22.x
         ↓
  Détecter le Chemin NPM Global
         ↓
 Mettre en Cache les Paquets NPM Globaux
         ↓
 Installer Copilot CLI
         ↓
  Obtenir les Différences de la PR
    (API Azure DevOps)
         ↓
 Télécharger les Fichiers Modifiés
         ↓
Analyser avec Copilot
  (Identifie les problèmes)
         ↓
Extraire les Informations de la PR
   (Org, Projet, Dépôt, ID PR)
         ↓
Publier un Commentaire sur la PR
         ↓
   Publier les Artefacts
         ↓
   ✅ Révision Complète
```

## 🚀 Installation

### Prérequis

1. **Azure DevOps** avec permissions pour :
   - Créer des pipelines
   - Configurer les variables de pipeline
   - Accéder aux Pull Requests

2. **Compte GitHub** avec :
   - Accès à GitHub Copilot
   - Personal Access Token avec permissions Copilot

3. **Agent de Build** avec :
   - Node.js 18.x ou supérieur
   - Git
   - Bash

### Configuration

#### 1. Créer un Variable Group

Créez un **Variable Group** nommé `GitHub Copilot CLI` avec les variables suivantes :

**Variables Requises:**
- `AZURE_DEVOPS_EXT_PAT`: Personal Access Token Azure DevOps avec permissions pour :
  - **Code (Read)**: Pour lire les informations de PR et les fichiers modifiés
  - **Pull Request (Contribute)**: Pour créer des commentaires sur les PRs

**Instructions pour créer le PAT Azure DevOps:**
1. Allez dans votre profil utilisateur dans Azure DevOps (coin supérieur droit)
2. Sélectionnez "Personal access tokens"
3. Cliquez sur "New Token"
4. Configurez :
   - Name: "ReviewerAgent Pipeline"
   - Organization: Votre organisation
   - Expiration: Selon vos politiques de sécurité
   - Scopes: Sélectionnez "Code" (Read) et "Pull Request" (Contribute)
5. Copiez le token généré et sauvegardez-le comme `AZURE_DEVOPS_EXT_PAT` dans le Variable Group

**Important:** Marquez la variable comme "Secret" pour protéger le token

#### 2. Configurer le Pipeline

1. Dans votre projet Azure DevOps, allez dans **Pipelines** → **New Pipeline**
2. Sélectionnez votre dépôt
3. Choisissez "Existing Azure Pipelines YAML file"
4. Sélectionnez le fichier `azure-pipelines.yml`
5. Sauvegardez le pipeline

#### 3. Configurer le Modèle et la Version (Optionnel)

Dans le fichier `azure-pipelines.yml`, vous pouvez configurer :

```yaml
variables:
  - group: "GitHub Copilot CLI"
  - name: MODEL
    value: claude-sonnet-4  # Changez le modèle selon votre préférence
  - name: COPILOT_VERSION
    value: "latest"         # ou spécifiez une version fixe comme "0.0.339"
```

**Modèles disponibles:**
- `claude-sonnet-4` (recommandé)
- `gpt-4o`
- `o1-preview`
- `o1-mini`

## 📁 Scripts Inclus

### 1. `get-pr-diff.sh`
Obtient les différences d'une Pull Request en utilisant l'API Azure DevOps.

**Paramètres:**
- `SOURCE_REPO_URI`: URI du dépôt
- `SOURCE_BRANCH`: Branche source
- `TARGET_BRANCH`: Branche cible
- `PAT`: Personal Access Token
- `OUTPUT_FILE`: Fichier de sortie

**Utilisation:**
```bash
./scripts/get-pr-diff.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/output.json'
```

### 2. `download-pr-files.sh`
Télécharge les fichiers modifiés dans une PR, en les organisant dans des répertoires temporaires par branche.

**Paramètres:**
- `DIFF_FILE`: Fichier JSON de diff
- `SOURCE_REPO_URI`: URI du dépôt
- `SOURCE_BRANCH`: Branche source
- `TARGET_BRANCH`: Branche cible
- `PAT`: Personal Access Token
- `OUTPUT_DIR`: Répertoire de sortie

**Utilisation:**
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
Analyse les fichiers en utilisant GitHub Copilot CLI et génère un commentaire de révision de PR.

**Paramètres:**
- `SOURCE_DIR`: Répertoire avec les fichiers téléchargés

**Utilisation:**
```bash
./scripts/analyze-with-copilot.sh '/path/to/downloaded/files'
```

### 4. `post-pr-comment.sh`
Publie des commentaires de révision sur les Pull Requests Azure DevOps.

**Paramètres:**
- `COMMENT_DIR`: Répertoire avec les commentaires à publier
- `ORG`: Organisation Azure DevOps
- `PROJECT`: Projet Azure DevOps
- `REPO`: Dépôt
- `PR_ID`: ID de la Pull Request
- `PAT`: Personal Access Token

**Utilisation:**
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
Script complet qui combine l'obtention du diff et le téléchargement des fichiers.

**Utilisation:**
```bash
./scripts/get-and-download-pr-files.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/output-dir'
```

### 6. `complete-pr-analysis.sh` (Flux complet)
Script qui exécute l'ensemble du flux : obtenir le diff, télécharger les fichiers et analyser avec Copilot.

**Utilisation:**
```bash
./scripts/complete-pr-analysis.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/analysis-dir'
```

### 7. `example-usage.sh`
Script de démonstration montrant comment utiliser tous les composants.

## 🏗️ Architecture

### Templates Réutilisables

Le projet utilise des templates Azure DevOps pour améliorer la maintenabilité :

**`templates/run-script.yml`**: Template générique pour exécuter des scripts bash
- Simplifie l'invocation des scripts
- Gère les erreurs automatiquement
- Propage les variables d'environnement nécessaires
- Permet la personnalisation du répertoire de travail

**Utilisation du template:**
```yaml
- template: templates/run-script.yml
  parameters:
    script: my-script.sh
    args: '"arg1" "arg2"'
    displayName: 🔧 Mon Étape
    workingDirectory: $(Build.SourcesDirectory)
```

### Cache NPM

Le pipeline implémente la mise en cache des paquets NPM globaux pour optimiser les temps :
- Détecte automatiquement le chemin NPM global
- Met en cache les installations de `@github/copilot`
- Réduit le temps d'installation dans les builds ultérieurs
