# 🤖 Azure DevOps Reviewer Agent

<div align="center">

[![YouTube Channel Subscribers](https://img.shields.io/youtube/channel/subscribers/UC140iBrEZbOtvxWsJ-Tb0lQ?style=for-the-badge&logo=youtube&logoColor=white&color=red)](https://www.youtube.com/c/GiselaTorres?sub_confirmation=1)
[![GitHub followers](https://img.shields.io/github/followers/0GiS0?style=for-the-badge&logo=github&logoColor=white)](https://github.com/0GiS0)
[![LinkedIn Follow](https://img.shields.io/badge/LinkedIn-Sígueme-blue?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/giselatorresbuitrago/)
[![X Follow](https://img.shields.io/badge/X-Sígueme-black?style=for-the-badge&logo=x&logoColor=white)](https://twitter.com/0GiS0)

**🌍 Idiomas:** 🇪🇸 **Español** | [🇬🇧 English](README.en.md) | [🇫🇷 Français](README.fr.md)

</div>

¡Hola developer 👋🏻! Este repositorio implementa un flujo en Azure Pipelines 🚀 que integra **GitHub Copilot CLI** 🤖 para revisar automáticamente Pull Requests e identificar problemas potenciales en el código. El código fue utilizado para mi vídeo: [🚀 Lleva Azure DevOps al siguiente nivel con GitHub Copilot CLI 🤖](https://youtu.be/ZS0LQA2_zZQ)

<a href="https://youtu.be/ZS0LQA2_zZQ">
 <img src="https://img.youtube.com/vi/ZS0LQA2_zZQ/maxresdefault.jpg" alt="🚀 Lleva Azure DevOps al siguiente nivel con GitHub Copilot CLI 🤖" width="100%" />
</a>

### 🎯 Objetivos

- ✅ Automatizar la revisión de código mediante IA (GitHub Copilot)
- ✅ Integrar GitHub Copilot CLI con Azure DevOps
- ✅ Analizar Pull Requests automáticamente en cada cambio
- ✅ Identificar problemas potenciales de seguridad, rendimiento y calidad
- ✅ Publicar comentarios de revisión automáticos en las PRs

## 🚀 ¿Qué hace?

El pipeline se activa automáticamente cuando se crea o actualiza una Pull Request y realiza el siguiente flujo:

1. 📋 **Obtiene las diferencias del PR** - Descarga los cambios usando Azure DevOps API
2. 📁 **Descarga archivos modificados** - Organiza los archivos por rama (origen y destino)
3. 🤖 **Ejecuta GitHub Copilot CLI** - Analiza el código con IA para identificar problemas
4. 💬 **Publica comentarios** - Crea comentarios automáticos en la PR con los hallazgos
5. 📦 **Genera artefactos** - Guarda el análisis completo para referencia

## 👀 Tecnologías Utilizadas

- **Azure DevOps** - Gestión de Pull Requests y pipelines
- **GitHub Copilot CLI** - Análisis automático de código con IA
- **Bash Scripts** - Automatización y orquestación
- **Node.js 22.x** - Runtime para Copilot CLI
- **Azure Pipelines YAML** - Definición del flujo de trabajo

## 📦 Estructura del Proyecto

```
├── azure-pipelines.yml              # Definición del pipeline
├── templates/
│   └── run-script.yml              # Template reutilizable para ejecutar scripts
├── scripts/                         # Scripts de automatización
│   ├── get-pr-diff.sh              # Obtiene diferencias del PR
│   ├── download-pr-files.sh        # Descarga archivos modificados
│   ├── analyze-with-copilot.sh     # Analiza con GitHub Copilot
│   ├── post-pr-comment.sh          # Publica comentarios en la PR
│   ├── get-and-download-pr-files.sh # Wrapper: diff + descarga
│   ├── complete-pr-analysis.sh     # Flujo completo: diff + descarga + análisis
│   └── example-usage.sh            # Ejemplos de uso
└── README.md                        # Este archivo
```

## ⚙️ Configuración Requerida

### Variables de Entorno

- `AZURE_DEVOPS_EXT_PAT` - Personal Access Token de Azure DevOps con permisos de Code (Read/Write)
- `MODEL` - Modelo de lenguaje a utilizar (ej. claude-sonnet-4)
- `COPILOT_VERSION` - Versión de Copilot CLI a instalar (ej. latest o versión específica)

## 📝 Cómo Funciona el Pipeline - Paso a Paso

El pipeline ejecuta los siguientes pasos de forma automática cuando se crea o actualiza una PR:

### 🔧 Paso 1: Mostrar Información del PR

**Comando:** `📋 Show PR Information`

Imprime información de debug en los logs:
- Repository URI (URL del repositorio)
- PR # (número de la PR)
- Source Branch (rama con los cambios)
- Target Branch (rama destino del merge)
- Source Commit (commit actual)
- Build Repository y Commit
- Directorios de trabajo (Analysis Dir, Diff File)

### ⚙️ Paso 2: Setup Node.js 22.x

**Comando:** `⚙️ Setup Node.js 22.x`

- Instala Node.js versión 22.x en el agente de build
- Necesario porque Copilot CLI es una herramienta Node

### 🔍 Paso 3: Detectar Ruta NPM Global

**Comando:** `🔍 Detect NPM Global Path`

```bash
NPM_PREFIX=$(npm config get prefix)
```

- Obtiene la ruta donde npm instala paquetes globales (ej: `/usr/local/lib/node_modules`)
- Guarda esa ruta en la variable `NPM_GLOBAL_PATH` para usar en el cache

### 📦 Paso 4: Cachear Paquetes NPM

**Comando:** `📦 Cache Global NPM Packages`

- **Clave de cache:** `npm-global | OS | copilot | COPILOT_VERSION`
- **Ruta cacheada:** La ruta global de NPM del paso anterior
- **Beneficio:** Builds posteriores usan el cache sin re-descargar @github/copilot (ahorra 30-60 segundos)

### 📦 Paso 5: Instalar Copilot CLI

**Comando:** `📦 Install Copilot CLI`

```bash
if ! command -v copilot &> /dev/null; then
  npm install -g @github/copilot@$(COPILOT_VERSION)
else
  echo "✅ @github/copilot already installed (from cache)"
fi
```

- Verifica si copilot ya está instalado (desde cache)
- Si no está, lo instala: `npm install -g @github/copilot@latest`
- Si está en cache, salta la descarga

### 🔍 Paso 6: Obtener Diferencias del PR

**Comando:** `🔍 Get PR Differences`

**Ejecuta:** `scripts/get-pr-diff.sh` con:
```bash
./scripts/get-pr-diff.sh \
  "$(System.PullRequest.SourceRepositoryUri)" \
  "$(System.PullRequest.SourceBranch)" \
  "$(System.PullRequest.TargetBranch)" \
  "$(AZURE_DEVOPS_EXT_PAT)" \
  "$(DIFF_FILE)"
```

**Qué hace:**
- Llama a Azure DevOps REST API
- Obtiene todas las diferencias entre ramas (archivos añadidos, modificados, eliminados)
- Guarda resultado en JSON: `$(Build.ArtifactStagingDirectory)/pr-diff.json`

### 📁 Paso 7: Descargar Archivos Modificados

**Comando:** `📁 Download Modified Files`

**Ejecuta:** `scripts/download-pr-files.sh` con:
```bash
./scripts/download-pr-files.sh \
  "$(DIFF_FILE)" \
  "$(System.PullRequest.SourceRepositoryUri)" \
  "$(System.PullRequest.SourceBranch)" \
  "$(System.PullRequest.TargetBranch)" \
  "$(AZURE_DEVOPS_EXT_PAT)" \
  "$(ANALYSIS_DIR)"
```

**Qué hace:**
- Lee el archivo JSON del diff (paso anterior)
- Descarga archivos en 2 directorios organizados:
  - `$(ANALYSIS_DIR)/source/` - Archivos de la rama fuente (con cambios)
  - `$(ANALYSIS_DIR)/target/` - Archivos de la rama destino (sin cambios)
- Mantiene la estructura de carpetas original

### 🤖 Paso 8: Analizar con GitHub Copilot CLI

**Comando:** `🤖 Analyze with GitHub Copilot CLI`

**Ejecuta:** `scripts/analyze-with-copilot.sh` con:
```bash
./scripts/analyze-with-copilot.sh "$(ANALYSIS_DIR)/source"
```

**Qué hace:**
- Ejecuta copilot CLI con modelo `claude-sonnet-4` (configurable)
- Analiza los archivos descargados buscando problemas:
  - 🔒 **Seguridad** - Vulnerabilidades, acceso no autorizados, validación
  - ⚡ **Rendimiento** - Bucles ineficientes, operaciones costosas
  - 🧹 **Código Limpio** - Refactoring, nombres variables, duplicación
  - 📝 **TypeScript** - Tipado, interfaces, tipos genéricos
  - 🐛 **Bugs** - Lógica errónea, null checks, edge cases
- Genera comentarios Markdown: `$(ANALYSIS_DIR)/source/pr-comments/`

### 📋 Paso 9: Extraer Información del PR

**Comando:** `📋 Extract PR Info`

**Qué hace:**
```bash
REPO_URI="$(System.PullRequest.SourceRepositoryUri)"
# Extrae: https://dev.azure.com/returngisorg/GitHub%20Copilot%20CLI/_git/ReviewerAgent
ORG="returngisorg"              # Organización
PROJECT="GitHub Copilot CLI"    # Proyecto
REPO="ReviewerAgent"            # Repositorio
PR_ID="123"                     # ID de la PR
```

- Parsea la URL del repositorio
- Extrae componentes necesarios para la API de Azure DevOps
- Guarda en variables: `PR_ORG`, `PR_PROJECT`, `PR_REPO`, `PR_NUM`

### 💬 Paso 10: Publicar Comentario en PR

**Comando:** `💬 Publish Comment on PR`

**Ejecuta:** `scripts/post-pr-comment.sh` con:
```bash
./scripts/post-pr-comment.sh \
  "$(ANALYSIS_DIR)/source/pr-comments" \
  "$(PR_ORG)" \
  "$(PR_PROJECT)" \
  "$(PR_REPO)" \
  "$(PR_NUM)" \
  "$(AZURE_DEVOPS_EXT_PAT)"
```

**Qué hace:**
- Lee los comentarios generados por Copilot (paso 8)
- Conecta a Azure DevOps API usando PAT
- Publica comentarios directamente en la PR
- **Resultado:** Los desarrolladores ven en la PR exactamente qué problemas encontró Copilot

### 📦 Paso 11: Publicar Artefactos

**Comando:** `📦 Publish Complete Analysis as Artifact`

**Qué hace:**
- Publica toda la carpeta `$(Build.ArtifactStagingDirectory)` como artefacto
- Nombre del artefacto: `pr-analysis-complete`
- **Contenido descargable:**
  - `pr-diff.json` - Diferencias completas en formato JSON
  - `pr-analysis/source/` - Todos los archivos analizados
  - `pr-analysis/source/pr-comments/` - Comentarios generados
  - Logs completos de ejecución

**Beneficio:** Los usuarios pueden descargar y revisar el análisis completo desde Azure Pipelines

## 📝 Cómo Funciona el Pipeline - Paso a Paso

El pipeline ejecuta los siguientes pasos de forma automática cuando se crea o actualiza una PR:

### 🔧 Preparación del Entorno
1. **📋 Mostrar Información del PR** - Imprime datos de la PR (repositorio, rama, commit)
2. **⚙️ Setup Node.js 22.x** - Instala Node.js para Copilot CLI
3. **🔍 Detectar Ruta NPM** - Localiza la ruta global de NPM
4. **📦 Cache de Paquetes NPM** - Cachea paquetes globales para acelerar ejecuciones futuras
5. **📦 Instalar Copilot CLI** - Instala @github/copilot en la versión especificada

### 📊 Análisis del PR
6. **🔍 Obtener Diferencias del PR** - Extrae los cambios usando Azure DevOps API
7. **📁 Descargar Archivos Modificados** - Descarga archivos de ambas ramas (origen y destino)
8. **🤖 Analizar con GitHub Copilot** - Ejecuta Copilot para revisar el código
9. **📋 Extraer Información del PR** - Obtiene datos como organización, proyecto, repositorio e ID del PR

### 📤 Publicación de Resultados
10. **💬 Publicar Comentario en PR** - Publica los hallazgos como comentario en la PR
11. **📦 Publicar Artefactos** - Guarda el análisis completo como artefacto de build

## 🔄 Flujo de Trabajo Completo

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
  (Identifica problemas)
         ↓
Extract PR Info
   (Org, Proyecto, Repo, PR ID)
         ↓
Publish Comment on PR
         ↓
   Publish Artifacts
         ↓
   ✅ Review Complete
```

## 🚀 Instalación

### Prerrequisitos

1. **Azure DevOps** con permisos para:
   - Crear pipelines
   - Configurar variables de pipeline
   - Acceder a Pull Requests

2. **GitHub Account** con:
   - Acceso a GitHub Copilot
   - Personal Access Token con permisos de Copilot

3. **Agente de Build** con:
   - Node.js 18.x o superior
   - Git
   - Bash

### Configuración

#### 1. Crear un Variable Group

Crea un **Variable Group** llamado `GitHub Copilot CLI` con las siguientes variables:

**Variables Requeridas:**
- `AZURE_DEVOPS_EXT_PAT`: Personal Access Token de Azure DevOps con permisos para:
  - **Code (Read)**: Para leer información de PRs y archivos modificados
  - **Pull Request (Contribute)**: Para crear comentarios en PRs

**Instrucciones para crear el PAT de Azure DevOps:**
1. Ve a tu perfil de usuario en Azure DevOps (esquina superior derecha)
2. Selecciona "Personal access tokens"
3. Haz clic en "New Token"
4. Configura:
   - Name: "ReviewerAgent Pipeline"
   - Organization: Tu organización
   - Expiration: Según tus políticas de seguridad
   - Scopes: Selecciona "Code" (Read) y "Pull Request" (Contribute)
5. Copia el token generado y guárdalo como `AZURE_DEVOPS_EXT_PAT` en el Variable Group

**Importante:** Marca la variable como "Secret" para proteger el token

#### 2. Configurar la Pipeline

1. En tu proyecto de Azure DevOps, ve a **Pipelines** → **New Pipeline**
2. Selecciona tu repositorio
3. Elige "Existing Azure Pipelines YAML file"
4. Selecciona el archivo `azure-pipelines.yml`
5. Guarda la pipeline

#### 3. Configurar Modelo y Versión (Opcional)

En el archivo `azure-pipelines.yml`, puedes configurar:

```yaml
variables:
  - group: "GitHub Copilot CLI"
  - name: MODEL
    value: claude-sonnet-4  # Cambia el modelo según tu preferencia
  - name: COPILOT_VERSION
    value: "latest"         # o especifica una versión fija como "0.0.339"
```

**Modelos disponibles:**
- `claude-sonnet-4` (recomendado)
- `gpt-4o`
- `o1-preview`
- `o1-mini`

## 📁 Scripts Incluidos

### 1. `get-pr-diff.sh`
Obtiene las diferencias de un Pull Request usando la API de Azure DevOps.

**Parámetros:**
- `SOURCE_REPO_URI`: URI del repositorio
- `SOURCE_BRANCH`: Rama fuente
- `TARGET_BRANCH`: Rama destino
- `PAT`: Personal Access Token
- `OUTPUT_FILE`: Archivo de salida

**Uso:**
```bash
./scripts/get-pr-diff.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/output.json'
```

### 2. `download-pr-files.sh`
Descarga los archivos modificados en un PR, organizándolos en directorios temporales por rama.

**Parámetros:**
- `DIFF_FILE`: Archivo de diff JSON
- `SOURCE_REPO_URI`: URI del repositorio
- `SOURCE_BRANCH`: Rama fuente
- `TARGET_BRANCH`: Rama destino
- `PAT`: Personal Access Token
- `OUTPUT_DIR`: Directorio de salida

**Uso:**
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
Analiza archivos usando GitHub Copilot CLI y genera un comentario de revisión de PR.

**Parámetros:**
- `SOURCE_DIR`: Directorio con archivos descargados

**Uso:**
```bash
./scripts/analyze-with-copilot.sh '/path/to/downloaded/files'
```

### 4. `post-pr-comment.sh`
Publica comentarios de revisión en Pull Requests de Azure DevOps.

**Parámetros:**
- `COMMENT_DIR`: Directorio con comentarios a publicar
- `ORG`: Organización de Azure DevOps
- `PROJECT`: Proyecto de Azure DevOps
- `REPO`: Repositorio
- `PR_ID`: ID del Pull Request
- `PAT`: Personal Access Token

**Uso:**
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
Script completo que combina la obtención del diff y descarga de archivos.

**Uso:**
```bash
./scripts/get-and-download-pr-files.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/output-dir'
```

### 6. `complete-pr-analysis.sh` (Flujo completo)
Script que ejecuta todo el flujo: obtener diff, descargar archivos y analizar con Copilot.

**Uso:**
```bash
./scripts/complete-pr-analysis.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/analysis-dir'
```

### 7. `example-usage.sh`
Script de demostración que muestra cómo usar todos los componentes.

## 🏗️ Arquitectura

### Templates Reutilizables

El proyecto utiliza templates de Azure DevOps para mejorar la mantenibilidad:

**`templates/run-script.yml`**: Template genérico para ejecutar scripts bash
- Simplifica la invocación de scripts
- Maneja errores automáticamente
- Propaga variables de entorno necesarias
- Permite personalizar el directorio de trabajo

**Uso del template:**
```yaml
- template: templates/run-script.yml
  parameters:
    script: mi-script.sh
    args: '"arg1" "arg2"'
    displayName: 🔧 Mi Paso
    workingDirectory: $(Build.SourcesDirectory)
```

### Cache de NPM

La pipeline implementa cache de paquetes NPM globales para optimizar tiempos:
- Detecta automáticamente la ruta de NPM global
- Cachea instalaciones de `@github/copilot`
- Reduce tiempo de instalación en builds posteriores

