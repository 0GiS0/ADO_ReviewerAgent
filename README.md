# 🤖 Reviewer Agent - Azure DevOps PR Analyzer

Un agente automatizado que utiliza GitHub Copilot CLI para revisar Pull Requests en Azure DevOps, identificar problemas potenciales y publicar comentarios de revisión directamente en las PRs.

## 📋 Descripción

Este proyecto proporciona una pipeline completa de Azure DevOps que:

1. ✅ Se ejecuta automáticamente en cada Pull Request
2. 🔍 Obtiene diferencias del PR usando Azure DevOps API
3. 📁 Descarga archivos modificados organizados por rama
4. 🤖 Analiza los cambios de código usando GitHub Copilot CLI
5. 📝 Genera un comentario de revisión detallado en formato Markdown
6. 💬 Publica automáticamente el comentario de revisión en la PR

## 🎯 Características

- **Pipeline Completa**: Flujo automatizado de análisis completo de PRs
- **Integración con Azure DevOps API**: Obtención y descarga automática de archivos modificados
- **Análisis con IA**: Utiliza GitHub Copilot CLI para análisis inteligente de calidad y seguridad
- **Comentarios Automáticos**: Publica comentarios de revisión directamente en las PRs
- **Pasos Separados**: Pipeline modular con pasos independientes para fácil depuración
- **Artefactos Completos**: Genera archivos de análisis disponibles como artefactos de build
- **Manejo de Errores**: Gestión robusta de errores en cada paso del proceso

## 📁 Scripts Incluidos

### 1. `get-pr-diff.sh`
Obtiene las diferencias de un Pull Request usando la API de Azure DevOps.

### 2. `download-pr-files.sh`
Descarga los archivos modificados en un PR, organizándolos en directorios temporales por rama.

### 3. `analyze-with-copilot.sh`
Analiza archivos usando GitHub Copilot CLI y genera un comentario de revisión de PR.

### 4. `post-pr-comment.sh`
Publica comentarios de revisión en Pull Requests de Azure DevOps.

### 5. `get-and-download-pr-files.sh` (Wrapper)
Script completo que combina la obtención del diff y descarga de archivos.

### 6. `complete-pr-analysis.sh` (Flujo completo)
Script que ejecuta todo el flujo: obtener diff, descargar archivos y analizar con Copilot.

### 7. `example-usage.sh`
Script de demostración que muestra cómo usar todos los componentes.

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
   - Bash/PowerShell

### Configuración

#### 1. Configurar Variables en Azure DevOps

Ve a tu proyecto en Azure DevOps y configura las siguientes variables:

**Pipeline Variables:**
- `GITHUB_TOKEN`: Tu Personal Access Token de GitHub con acceso a Copilot
  - Marca esta variable como **secreta**
  - Obtén el token en: https://github.com/settings/tokens

#### 1. Crear un Variable Group

Crea un **Variable Group** llamado `GitHub Copilot CLI` con las siguientes variables:

**Variables Requeridas:**
- `GITHUB_TOKEN`: Token de GitHub con acceso a Copilot (generado en GitHub → Settings → Developer settings → Personal access tokens)
- `AZURE_DEVOPS_EXT_PAT`: Personal Access Token de Azure DevOps con permisos para:
  - **Code (Read)**: Para leer información de PRs
  - **Code (Write)**: Para crear comentarios en PRs
  - Genera el PAT en: Azure DevOps → User Settings → Personal access tokens → New Token

**Instrucciones para crear el PAT de Azure DevOps:**
1. Ve a tu perfil de usuario en Azure DevOps (esquina superior derecha)
2. Selecciona "Personal access tokens"
3. Haz clic en "New Token"
4. Configura:
   - Name: "ReviewerAgent Pipeline"
   - Organization: Tu organización
   - Expiration: Según tus políticas de seguridad
   - Scopes: Selecciona "Code" con permisos Read y Write
5. Copia el token generado y guárdalo como `AZURE_DEVOPS_EXT_PAT` en el Variable Group

**Importante:** 
- Marca ambas variables como "Secret" para proteger los tokens
- El `AZURE_DEVOPS_EXT_PAT` es necesario porque el `System.AccessToken` por defecto puede tener permisos insuficientes para crear threads en PRs

#### 2. Configurar la Pipeline

1. En tu proyecto de Azure DevOps, ve a **Pipelines** → **New Pipeline**
2. Selecciona tu repositorio
3. Elige "Existing Azure Pipelines YAML file"
4. Selecciona el archivo `azure-pipelines.yml`
5. Guarda la pipeline

#### 3. Configurar Permisos del Build Service (Opcional)

Si decides usar el `System.AccessToken` en lugar del PAT personalizado, asegúrate de que el Build Service tenga permisos para contribuir a PRs:

1. **Contribuir a Pull Requests:**
   - Ve a **Project Settings** → **Repositories** → Tu repositorio
   - En "Security", busca el usuario "Build Service"
   - Otorga permisos de "Contribute to pull requests"

**Nota:** Al usar `AZURE_DEVOPS_EXT_PAT`, estos permisos del Build Service no son necesarios, ya que el PAT ya tiene los permisos configurados.

## 📖 Uso

### Uso Automático

Una vez configurada, la pipeline se ejecutará automáticamente cuando:

- Se crea una nueva Pull Request
- Se agregan nuevos commits a una PR existente
- La PR apunta a las ramas: `main`, `develop`, o cualquier rama `feature/*`

### Uso Manual de Scripts

Los scripts también se pueden ejecutar manualmente:

#### 🔍 Obtener diferencias de PR:
```bash
./scripts/get-pr-diff.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/output.json'
```

#### 📁 Descargar archivos modificados:
```bash
./scripts/download-pr-files.sh \
  '/path/to/diff.json' \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/output-dir'
```

#### 🚀 Proceso completo (obtener diff + descargar archivos):
```bash
./scripts/get-and-download-pr-files.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/output-dir'
```

#### 🤖 Analizar archivos con GitHub Copilot CLI:
```bash
./scripts/analyze-with-copilot.sh \
  '/path/to/downloaded/files' \
  '/path/to/output/pr-comment.md'
```

#### 🎯 Flujo completo (diff + descarga + análisis con Copilot):
```bash
./scripts/complete-pr-analysis.sh \
  'https://user@dev.azure.com/org/project/_git/repo' \
  'refs/heads/feature-branch' \
  'refs/heads/main' \
  'your-pat-token' \
  '/path/to/analysis-dir'
```

#### Analizar código con Copilot:
```bash
chmod +x scripts/analyze-with-copilot.sh
./scripts/analyze-with-copilot.sh <archivo> <diff_file> <output_file>
```

#### Publicar comentarios en PR:
```powershell
./scripts/post-pr-comment.ps1 `
  -ReportPath "report.md" `
  -OrgUrl "https://dev.azure.com/tu-org/" `
  -Project "tu-proyecto" `
  -RepoId "repo-id" `
  -PrId "123" `
  -AccessToken "tu-token"
```

#### Configurar Copilot localmente:
```bash
chmod +x scripts/setup-copilot.sh
./scripts/setup-copilot.sh
```

### 📋 Parámetros de los Scripts de Descarga

**Parámetros comunes:**
- `SOURCE_REPO_URI`: URI completa del repositorio (ej: `https://user@dev.azure.com/org/project/_git/repo`)
- `SOURCE_BRANCH`: Rama fuente del PR (ej: `refs/heads/feature-branch`)
- `TARGET_BRANCH`: Rama destino del PR (ej: `refs/heads/main`)
- `PAT`: Personal Access Token con permisos de lectura en el repositorio
- `OUTPUT_DIR`: [Opcional] Directorio de salida (por defecto: `./pr-files-TIMESTAMP`)

**Estructura de salida generada:**
```
output-directory/
├── source/           # Archivos de la rama fuente
├── target/           # Archivos de la rama destino
└── metadata/
    ├── pr-info.json  # Información del PR y estadísticas
    └── original-diff.json # Diff completo en formato JSON
```

## 📁 Estructura del Proyecto

```
ReviewerAgent/
├── azure-pipelines.yml          # Pipeline principal
├── scripts/
│   ├── analyze-with-copilot.sh  # Script de análisis
│   ├── post-pr-comment.ps1      # Script para publicar comentarios
│   └── setup-copilot.sh         # Script de configuración
└── README.md                    # Este archivo
```

## 🔧 Configuración Avanzada

### Personalizar el Análisis

Puedes modificar el análisis editando la sección correspondiente en `azure-pipelines.yml`:

```yaml
# Agregar análisis personalizados
if grep -q "tu-patrón" "$file" 2>/dev/null; then
  echo "- **Tu Check:** Mensaje personalizado" >> $(REVIEW_OUTPUT)
  issue_count=$((issue_count + 1))
fi
```

### Cambiar las Ramas de Trigger

Modifica la sección `pr:` en `azure-pipelines.yml`:

```yaml
pr:
  branches:
    include:
      - main
      - develop
      - release/*
```

### Personalizar el Formato del Reporte

El reporte se genera en formato Markdown. Puedes personalizar el formato editando las líneas `echo` en el script de análisis.

## 🐛 Solución de Problemas

### Error: "GitHub Copilot CLI not found"

**Solución:** Asegúrate de que el paso de instalación de Copilot CLI se ejecute correctamente:

```bash
npm install -g @githubnext/github-copilot-cli
# o
gh extension install github/gh-copilot
```

### Error: "Access denied to Pull Request"

**Solución:** Verifica que:
1. `System.AccessToken` esté habilitado en la pipeline
2. El usuario "Build Service" tenga permisos de "Contribute to pull requests"

### Error: "GITHUB_TOKEN not configured"

**Solución:** 
1. Ve a Pipeline → Edit → Variables
2. Agrega `GITHUB_TOKEN` como variable secreta
3. Asegúrate de que el token tenga acceso a Copilot

### Los comentarios no aparecen en la PR

**Solución:**
1. Verifica que `System.AccessToken` tenga permisos
2. Revisa los logs de la pipeline para errores de API
3. Asegúrate de que el ID de la PR sea correcto

## 📊 Ejemplo de Reporte

Los reportes generados incluyen:

```markdown
# Reporte de Revisión de PR

**Pull Request:** #123
**Rama origen:** feature/new-feature
**Rama destino:** main
**Fecha:** 2025-10-13

---

## Archivo: src/app.ts

### Análisis de Copilot

- **Depuración:** Se encontraron statements console.log que deberían ser removidos
- **TypeScript:** Considerar tipar específicamente en lugar de usar any
- **Seguridad:** Validar entrada del usuario antes de procesar

---

## Resumen

- **Archivos revisados:** 5
- **Issues encontrados:** 8

Se encontraron 8 issues que requieren atención.
```

## 🤝 Contribuir

Las contribuciones son bienvenidas. Para contribuir:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/amazing-feature`)
3. Commit tus cambios (`git commit -m 'Add amazing feature'`)
4. Push a la rama (`git push origin feature/amazing-feature`)
5. Abre una Pull Request

## 📝 Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 🔗 Enlaces Útiles

- [Azure DevOps REST API](https://docs.microsoft.com/en-us/rest/api/azure/devops/)
- [GitHub Copilot CLI](https://githubnext.com/projects/copilot-cli/)
- [Azure Pipelines YAML Schema](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/)

## 💡 Tips

1. **Optimizar tiempos**: Limita el análisis solo a archivos relevantes (ej: solo .ts, .js, .py)
2. **Filtrar archivos**: Excluye archivos generados o de terceros
3. **Caché de dependencias**: Usa caché de npm para acelerar la instalación
4. **Análisis paralelo**: Para repositorios grandes, considera paralelizar el análisis

## 📞 Soporte

Si tienes problemas o preguntas:
- Abre un issue en este repositorio
- Consulta la documentación de Azure DevOps
- Revisa los logs de la pipeline para más detalles