# Setar variáveis de ambiente no PowerShell
$env:PROJECT_ID = "citadel-westeros-david"
$env:REGION = "us-central1"
$env:DB_INSTANCE_NAME = "citadel-vault-db"
$env:DB_NAME = "citadel_db"
$env:DB_USER = "maester"
$env:DB_PASS = "HighValyrianSecret123!"

gcloud config set project $env:PROJECT_ID

# 1. Habilitar APIs necessárias
gcloud services enable `
  run.googleapis.com `
  sqladmin.googleapis.com `
  aiplatform.googleapis.com `
  artifactregistry.googleapis.com

# 2. Criar repositório no Artifact Registry para a imagem Java
gcloud artifacts repositories create citadel-repo `
  --repository-format=docker `
  --location=$env:REGION

# 3. Criar instância do Cloud SQL (PostgreSQL 15+)
gcloud sql instances create $env:DB_INSTANCE_NAME `
  --database-version=POSTGRES_15 `
  --cpu=2 `
  --memory=7680MB `
  --region=$env:REGION `
  --root-password=$env:DB_PASS

# 4. Criar o Banco de Dados e Usuário
gcloud sql databases create $env:DB_NAME --instance=$env:DB_INSTANCE_NAME
gcloud sql users create $env:DB_USER --instance=$env:DB_INSTANCE_NAME --password=$env:DB_PASS
