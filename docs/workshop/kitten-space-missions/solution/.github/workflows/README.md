# 🚀 GitHub Actions Workflows

Automatización CI/CD para Kitten Space Missions usando GitHub Actions con OIDC authentication.

## 📋 Workflows Disponibles

### 1. `bicep-validation.yml` - Validación de Bicep en PRs

**Trigger:**
- Pull Requests que modifiquen archivos en `bicep/**`
- Manual dispatch

**Jobs:**

#### 🔍 Lint
- Valida sintaxis de todos los archivos Bicep
- Ejecuta `az bicep build` en main.bicep y todos los módulos
- Genera reporte de linting
- Falla el workflow si hay errores de sintaxis

#### 🏗️ Build
- Compila Bicep a ARM JSON
- Verifica que el template es válido
- Genera artifact con ARM template
- Muestra tamaño del template final

#### 🔒 Security Scan (Checkov)
- Escanea templates con Checkov
- Detecta misconfigurations de seguridad
- Genera SARIF report para GitHub Security
- Verifica compliance con best practices

#### 🔮 What-If Analysis
- Se conecta a Azure vía OIDC
- Ejecuta `az deployment sub what-if`
- Muestra recursos a crear/modificar/eliminar
- Genera resumen con contadores

#### 💬 Comment PR
- Combina resultados de todos los jobs
- Comenta en el PR con resumen completo
- Actualiza el comentario en cada push nuevo
- Incluye links a artifacts y logs

#### ✅ Validation Summary
- Job final que valida el estado general
- Falla si algún check crítico falló
- Requerido para merge (configurar como branch protection)

---

## 🔐 Configuración Requerida

### GitHub Secrets

Configura estos secrets en: `Settings → Secrets and variables → Actions`

| Secret | Descripción | Obtener con |
|--------|-------------|-------------|
| `AZURE_CLIENT_ID` | Service Principal App ID | Script OIDC setup |
| `AZURE_TENANT_ID` | Azure AD Tenant ID | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | `az account show --query id -o tsv` |
| `SQL_ADMIN_PASSWORD_DEV` | SQL Admin password para dev | Generado manualmente (seguro) |

### GitHub Environments

Crea estos environments en: `Settings → Environments`

#### `dev`
- **Protection rules**: None (para testing rápido)
- **Secrets**: `SQL_ADMIN_PASSWORD_DEV`

#### `prod` (futuro)
- **Protection rules**: 
  - Required reviewers: 2
  - Wait timer: 5 minutes
- **Secrets**: `SQL_ADMIN_PASSWORD_PROD`

### Branch Protection Rules

Configura en: `Settings → Branches → Branch protection rules`

Para `main` branch:
- ✅ Require a pull request before merging
- ✅ Require approvals: 1
- ✅ Require status checks to pass before merging:
  - `Bicep Linting`
  - `Bicep Build`
  - `Security Scan (Checkov)`
  - `Validation Summary`
- ✅ Require branches to be up to date before merging
- ✅ Include administrators

---

## 🧪 Testing del Workflow

### 1. Test Local de Linting

```bash
# Validar sintaxis localmente antes de push
az bicep build --file docs/workshop/kitten-space-missions/solution/bicep/main.bicep

# Lint todos los módulos
for module in docs/workshop/kitten-space-missions/solution/bicep/modules/*.bicep; do
  echo "Linting $module..."
  az bicep build --file "$module"
done
```

### 2. Test de Security Scan (Checkov)

```bash
# Instalar Checkov
pip install checkov

# Escanear Bicep files
checkov -d docs/workshop/kitten-space-missions/solution/bicep --framework bicep
```

### 3. Test de What-If

```bash
# Ejecutar what-if localmente
cd docs/workshop/kitten-space-missions/solution/bicep

az deployment sub what-if \
  --location westeurope \
  --template-file main.bicep \
  --parameters parameters/dev.parameters.json \
  --parameters sqlAdminPassword='YourPassword123!'
```

### 4. Trigger Manual del Workflow

```bash
# Desde GitHub UI: Actions → Bicep Validation → Run workflow

# O desde CLI con GitHub CLI
gh workflow run bicep-validation.yml
```

---

## 📊 Interpretación de Resultados

### ✅ Success
Todos los checks pasaron. El PR está listo para merge.

```
Linting: ✅ Passed
Build: ✅ Passed
Security Scan: ✅ Passed
What-If: ✅ Completed
```

### ⚠️ Warning
Hay warnings pero no errors críticos. Revisar antes de merge.

```
Linting: ✅ Passed (with warnings)
Build: ✅ Passed
Security Scan: ⚠️ Issues Found (check Security tab)
What-If: ✅ Completed
```

### ❌ Failure
Hay errores que deben corregirse antes de merge.

```
Linting: ❌ Failed (syntax errors)
Build: ⏭️ Skipped
Security Scan: ⏭️ Skipped
What-If: ⏭️ Skipped
```

---

## 🔍 Artifacts Generados

Cada workflow run genera artifacts disponibles por 30 días:

| Artifact | Contenido | Uso |
|----------|-----------|-----|
| `lint-results` | Reporte de linting en Markdown | Debugging de syntax errors |
| `arm-template` | Template ARM JSON compilado | Validación manual del output |
| `security-results` | Reporte Checkov + SARIF | Revisión de security issues |
| `whatif-results` | What-If summary + output raw | Análisis de cambios |

**Descargar artifacts:**
```bash
# Con GitHub CLI
gh run download <RUN_ID> -n whatif-results

# O desde UI: Actions → Run específico → Artifacts section
```

---

## 🐛 Troubleshooting

### Error: "OIDC token validation failed"

**Causa:** Federated credentials mal configurados

**Solución:**
```bash
# Verificar federated credentials
az ad app federated-credential list --id "$AZURE_CLIENT_ID" -o table

# El subject debe ser: repo:USERNAME/REPO:pull_request
```

### Error: "Permission denied on subscription"

**Causa:** Service Principal sin permisos

**Solución:**
```bash
# Verificar role assignments
az role assignment list \
  --assignee "$AZURE_CLIENT_ID" \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  -o table

# Debe tener rol "Contributor" en la subscription
```

### Error: "Checkov failed with critical issues"

**Causa:** Misconfigurations de seguridad detectadas

**Solución:**
1. Ver detalles en: `Security → Code scanning alerts`
2. Revisar el SARIF file en artifacts
3. Corregir issues y push de nuevo

**Bypass temporal (NO recomendado para prod):**
```yaml
# En bicep-validation.yml, cambiar:
soft_fail: true  # Permitir continuar con warnings
```

### Error: "What-If failed: Invalid parameter"

**Causa:** Password de SQL no configurado o inválido

**Solución:**
```bash
# Generar password seguro
PASSWORD=$(openssl rand -base64 32)

# Configurar secret en GitHub
gh secret set SQL_ADMIN_PASSWORD_DEV --body "$PASSWORD"
```

### Workflow no se dispara en PR

**Causa:** Path filter no matchea

**Solución:**
Verificar que los cambios están en:
```
docs/workshop/kitten-space-missions/solution/bicep/**
```

O editar el workflow para ajustar paths:
```yaml
on:
  pull_request:
    paths:
      - 'docs/workshop/kitten-space-missions/solution/bicep/**'
      - 'bicep/**'  # Agregar path adicional
```

---

## 📈 Métricas y Monitoring

### Ver historial de runs

```bash
# Últimos 10 workflow runs
gh run list --workflow=bicep-validation.yml --limit 10

# Detalles de un run específico
gh run view <RUN_ID>

# Ver logs de un job
gh run view <RUN_ID> --log --job=<JOB_ID>
```

### Estadísticas de éxito

```bash
# Tasa de éxito de los últimos 30 días
gh api repos/:owner/:repo/actions/workflows/bicep-validation.yml/runs \
  --jq '[.workflow_runs[] | select(.created_at > (now - 2592000 | todate)) | .conclusion] | group_by(.) | map({conclusion: .[0], count: length})'
```

---

## 🚀 Mejoras Futuras

### 1. Cost Estimation

Agregar job para estimar costos del deployment:

```yaml
- name: Cost Estimation
  run: |
    # Integrar con Azure Cost Management API o Infracost
    infracost breakdown --path main.json
```

### 2. Performance Testing

Agregar tests de performance post-deployment:

```yaml
- name: Load Testing
  run: |
    # Ejecutar k6 o Artillery contra el endpoint
    k6 run load-test.js
```

### 3. Drift Detection

Detectar drift entre código y estado real de Azure:

```yaml
- name: Drift Detection
  run: |
    # Comparar template con recursos existentes
    az deployment sub create --what-if --confirm-with-what-if
```

### 4. Auto-fix Security Issues

Generar PRs automáticos para fixes de Checkov:

```yaml
- name: Auto-fix Security
  uses: bridgecrewio/checkov-action@master
  with:
    auto_fix: true
```

---

## 📚 Referencias

- [GitHub Actions Documentation](https://docs.github.com/actions)
- [Azure Login Action (OIDC)](https://github.com/Azure/login)
- [Checkov for Bicep](https://www.checkov.io/5.Policy%20Index/bicep.html)
- [Bicep Best Practices](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)

---

**Última actualización:** Enero 2026  
**Mantenedor:** Azure Architect Pro Agent
