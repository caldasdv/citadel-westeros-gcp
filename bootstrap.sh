# Setar variáveis
export PROJECT_ID="citadel-westeros-david"
export REGION="us-central1"
export DB_INSTANCE_NAME="citadel-vault-db"
export DB_NAME="citadel_db"
export DB_USER="maester"
export DB_PASS="HighValyrianSecret123!"

gcloud config set project $PROJECT_ID

# 1. Habilitar APIs necessárias
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  aiplatform.googleapis.com \
  artifactregistry.googleapis.com

# 2. Criar repositório no Artifact Registry para a imagem Java
gcloud artifacts repositories create citadel-repo \
  --repository-format=docker \
  --location=$REGION

# 3. Criar instância do Cloud SQL (PostgreSQL 15+)
gcloud sql instances create $DB_INSTANCE_NAME \
  --database-version=POSTGRES_15 \
  --cpu=2 \
  --memory=7680MB \
  --region=$REGION \
  --root-password=$DB_PASS

# 4. Criar o Banco de Dados e Usuário
gcloud sql databases create $DB_NAME --instance=$DB_INSTANCE_NAME
gcloud sql users create $DB_USER --instance=$DB_INSTANCE_NAME --password=$DB_PASS
