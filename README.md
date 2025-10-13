# 🤖 Reviewer Agent - Azure DevOps PR Analyzer

Un agente automatizado que utiliza GitHub Copilot CLI para revisar Pull Requests en Azure DevOps, identificar problemas potenciales y publicar comentarios de revisión directamente en las PRs.

## 📋 Descripción

Este proyecto proporciona una pipeline de Azure DevOps que:

1. ✅ Se ejecuta automáticamente en cada Pull Request
2. 🔍 Analiza los cambios de código usando GitHub Copilot CLI
3. 📝 Genera un reporte detallado en formato Markdown
4. 💬 Publica los comentarios de revisión directamente en la PR de Azure DevOps

## 🎯 Características

- **Análisis Automatizado**: Revisión de código automática en cada PR
- **Detección de Problemas**: Identifica bugs, problemas de seguridad, y mejores prácticas
- **Reportes Detallados**: Genera reportes en Markdown con sugerencias concretas
- **Integración con Azure DevOps**: Publica comentarios directamente en las PRs
- **Personalizable**: Fácilmente extensible para agregar más análisis

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