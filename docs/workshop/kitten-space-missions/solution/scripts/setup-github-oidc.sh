#!/bin/bash
set -e

#############################################
# GitHub OIDC Setup for Azure
# Repository: fpinas-pdw/azure-agent-pro
#############################################

# 🎯 CONFIGURACIÓN
GITHUB_USERNAME="fpinas-pdw"
GITHUB_REPO="azure-agent-pro"
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
LOCATION="westeurope"
ENVIRONMENT_NAME="dev"

# Variables derivadas
RESOURCE_GROUP_NAME="rg-github-oidc-${GITHUB_REPO}"
APP_NAME="sp-github-${GITHUB_REPO}"
GITHUB_REPO_FULL="${GITHUB_USERNAME}/${GITHUB_REPO}"

echo "🔧 Configuración OIDC para GitHub Actions"
echo "=========================================="
echo "GitHub Repo: ${GITHUB_REPO_FULL}"
echo "Azure Subscription: ${AZURE_SUBSCRIPTION_ID}"
echo "Azure Tenant: ${TENANT_ID}"
echo "Location: ${LOCATION}"
echo ""

# 1️⃣ Crear Resource Group para metadata (opcional)
echo "📦 1. Creando Resource Group..."
az group create \
  --name "${RESOURCE_GROUP_NAME}" \
  --location "${LOCATION}" \
  --tags "Purpose=GitHubOIDC" "Repository=${GITHUB_REPO_FULL}" "ManagedBy=Script"

echo "   ✅ Resource Group creado: ${RESOURCE_GROUP_NAME}"

# 2️⃣ Crear App Registration (Service Principal)
echo "🆔 2. Creando App Registration..."
APP_ID=$(az ad app create \
  --display-name "${APP_NAME}" \
  --query appId \
  --output tsv)

echo "   ✅ App ID (Client ID): ${APP_ID}"

# Esperar propagación
echo "   ⏳ Esperando propagación de App Registration (10s)..."
sleep 10

# 3️⃣ Crear Service Principal
echo "🔑 3. Creando Service Principal..."
SP_OBJECT_ID=$(az ad sp create \
  --id "${APP_ID}" \
  --query id \
  --output tsv)

echo "   ✅ Service Principal Object ID: ${SP_OBJECT_ID}"

# Esperar propagación
echo "   ⏳ Esperando propagación de Service Principal (10s)..."
sleep 10

# 4️⃣ Asignar rol Contributor a nivel de Subscription
echo "👤 4. Asignando rol Contributor en Subscription..."
az role assignment create \
  --role "Contributor" \
  --assignee-object-id "${SP_OBJECT_ID}" \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}" \
  --description "GitHub Actions OIDC for ${GITHUB_REPO_FULL}"

echo "   ✅ Rol Contributor asignado"

# 5️⃣ Crear Federated Credential para Branch Main
echo "🔗 5. Creando Federated Credential para branch 'main'..."
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${GITHUB_REPO_FULL}"':ref:refs/heads/main",
    "description": "GitHub Actions for main branch",
    "audiences": [
      "api://AzureADTokenExchange"
    ]
  }'

echo "   ✅ Federated Credential para 'main' creada"

# 6️⃣ Crear Federated Credential para Pull Requests
echo "🔗 6. Creando Federated Credential para Pull Requests..."
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "github-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${GITHUB_REPO_FULL}"':pull_request",
    "description": "GitHub Actions for pull requests",
    "audiences": [
      "api://AzureADTokenExchange"
    ]
  }'

echo "   ✅ Federated Credential para Pull Requests creada"

# 7️⃣ Crear Federated Credential para Environment 'dev'
echo "🔗 7. Creando Federated Credential para environment 'dev'..."
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "github-environment-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${GITHUB_REPO_FULL}"':environment:'"${ENVIRONMENT_NAME}"'",
    "description": "GitHub Actions for dev environment",
    "audiences": [
      "api://AzureADTokenExchange"
    ]
  }'

echo "   ✅ Federated Credential para environment 'dev' creada"

# 8️⃣ Verificar configuración
echo ""
echo "🔍 8. Verificando configuración..."
echo ""
echo "Federated Credentials configurados:"
az ad app federated-credential list --id "${APP_ID}" \
  --query "[].{Name:name, Subject:subject}" -o table

echo ""
echo "✅ CONFIGURACIÓN COMPLETADA"
echo "============================"
echo ""
echo "📋 VALORES PARA GITHUB SECRETS:"
echo "--------------------------------"
echo "AZURE_CLIENT_ID: ${APP_ID}"
echo "AZURE_TENANT_ID: ${TENANT_ID}"
echo "AZURE_SUBSCRIPTION_ID: ${AZURE_SUBSCRIPTION_ID}"
echo ""
echo "🔗 Configura estos secrets en GitHub:"
echo "   https://github.com/${GITHUB_REPO_FULL}/settings/secrets/actions"
echo ""
echo "📝 PRÓXIMOS PASOS:"
echo "1. Ve a GitHub → Settings → Secrets and variables → Actions"
echo "2. Crea estos 3 Repository Secrets con los valores de arriba"
echo "3. Crea el environment 'dev' en: Settings → Environments → New environment"
echo "4. Ejecuta el workflow de prueba: .github/workflows/test-oidc.yml"
echo ""
echo "🧹 LIMPIAR (solo si necesitas revertir):"
echo "   az ad app delete --id ${APP_ID}"
echo "   az group delete --name ${RESOURCE_GROUP_NAME} --yes --no-wait"
echo ""

# Guardar valores en archivo temporal
cat > oidc-values.txt << EOF
AZURE_CLIENT_ID=${APP_ID}
AZURE_TENANT_ID=${TENANT_ID}
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
EOF

echo "💾 Valores guardados en: oidc-values.txt"
echo ""