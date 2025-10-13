# 🤝 Guía de Contribución

## Agregar Nuevos Scripts a la Pipeline

### Usando el Template `run-script.yml`

Para mantener la pipeline mantenible y consistente, usa el template `run-script.yml` para ejecutar scripts:

#### 1. Crea tu script en el directorio `scripts/`

```bash
#!/bin/bash

# Mi nuevo script
# Uso: ./mi-script.sh [args]

echo "🚀 Ejecutando mi script..."

# Tu lógica aquí
ARG1="${1}"
ARG2="${2}"

# Procesar...

if [ $? -eq 0 ]; then
  echo "✅ Script completado"
  exit 0
else
  echo "❌ Error en el script"
  exit 1
fi
```

#### 2. Haz el script ejecutable

```bash
chmod +x scripts/mi-script.sh
```

#### 3. Agrégalo a la pipeline usando el template

```yaml
- template: templates/run-script.yml
  parameters:
    script: mi-script.sh
    args: '"$(Variable1)" "$(Variable2)"'
    displayName: 🚀 Mi Nuevo Paso
    workingDirectory: $(System.DefaultWorkingDirectory)  # Opcional
```

### Parámetros del Template

| Parámetro | Tipo | Requerido | Descripción | Default |
|-----------|------|-----------|-------------|---------|
| `script` | string | ✅ Sí | Nombre del script en el directorio `scripts/` | - |
| `args` | string | ❌ No | Argumentos a pasar al script | `""` |
| `displayName` | string | ✅ Sí | Nombre del paso que aparecerá en Azure DevOps | - |
| `workingDirectory` | string | ❌ No | Directorio desde donde ejecutar el script | `$(System.DefaultWorkingDirectory)` |
| `env` | object | ❌ No | Variables de entorno adicionales | `{}` |

### Variables de Entorno Disponibles

El template automáticamente proporciona estas variables de entorno:

- `AZURE_DEVOPS_EXT_PAT`: Token de acceso personal de Azure DevOps
- `GH_TOKEN`: Token de GitHub (desde el variable group)
- `MODEL`: Modelo de Copilot configurado (ej: `claude-sonnet-4`)

### Ejemplo Avanzado con Variables de Entorno Personalizadas

```yaml
- template: templates/run-script.yml
  parameters:
    script: mi-script-avanzado.sh
    args: '"$(PrId)" "$(RepoName)"'
    displayName: 🔧 Script Avanzado
    workingDirectory: $(Build.SourcesDirectory)
    env:
      CUSTOM_VAR: "mi-valor"
      DEBUG_MODE: "true"
```

## Mejores Prácticas

### 1. Estructura de Scripts

```bash
#!/bin/bash

# Descripción clara del propósito
# Uso: ./script.sh <arg1> <arg2>

set -e  # Terminar en error

# Validar argumentos
if [ -z "$1" ]; then
  echo "❌ Error: Falta argumento 1"
  exit 1
fi

# Lógica del script
echo "🔧 Procesando..."

# Indicar éxito claramente
echo "✅ Completado exitosamente"
exit 0
```

### 2. Manejo de Errores

- Usa `set -e` para terminar en error
- Retorna códigos de salida apropiados (`0` = éxito, `1+` = error)
- Usa mensajes claros con emojis para facilitar debugging

### 3. Logging

```bash
echo "📋 Info: Mensaje informativo"
echo "⚠️  Warning: Advertencia"
echo "❌ Error: Algo salió mal"
echo "✅ Success: Operación completada"
```

### 4. Variables de Entorno

Documenta las variables de entorno requeridas:

```bash
#!/bin/bash

# Variables de entorno requeridas:
# - AZURE_DEVOPS_EXT_PAT: Token de Azure DevOps
# - MODEL: Modelo de Copilot a usar

MODEL="${MODEL:-claude-sonnet-4}"  # Default si no está definido
```

## Agregar Nuevos Modelos de Copilot

Para agregar soporte de nuevos modelos:

1. Actualiza la variable `MODEL` en `azure-pipelines.yml`:

```yaml
variables:
  - name: MODEL
    value: nuevo-modelo  # ej: gpt-4o, o1-preview
```

2. El script `analyze-with-copilot.sh` automáticamente usará este modelo

## Probar Cambios Localmente

Antes de hacer commit:

1. **Prueba el script manualmente:**
```bash
cd scripts
./mi-script.sh "arg1" "arg2"
```

2. **Verifica sintaxis YAML:**
```bash
# Instalar yamllint si no lo tienes
pip install yamllint

# Validar sintaxis
yamllint azure-pipelines.yml
```

3. **Prueba con una PR de prueba:**
- Crea una rama de prueba
- Abre una PR
- Observa la ejecución de la pipeline

## Modificar el Formato de Comentarios

El formato de comentarios se controla en el prompt de `scripts/analyze-with-copilot.sh`:

```bash
ANALYSIS_PROMPT="Analiza los archivos...

EJEMPLO DE FORMATO:

---
## 📝 Tu Formato Personalizado

### 📄 \`archivo.cs\`
...
"
```

Personaliza el formato según tus necesidades manteniendo la estructura Markdown.

## Soporte y Ayuda

Si tienes preguntas:
- Revisa los scripts existentes como ejemplos
- Consulta la documentación de Azure DevOps Pipelines
- Abre un issue con tus dudas
