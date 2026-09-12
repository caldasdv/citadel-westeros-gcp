# 🦅 Citadel Raven RAG — Enterprise GenAI com Java, Spring Boot & GCP

Bem-vindo ao workshop prático **Citadel Raven RAG**! Durante esta sessão, você construirá e implantará uma aplicação enterprise de Inteligência Artificial Gerativa pronta para produção, utilizando **Java 17**, **Spring Boot 3**, **Spring AI (v1.0.0-M1)** e serviços gerenciados da **Google Cloud Platform (GCP)**.

Inspirado no universo de *Game of Thrones*, o sistema atua como o **Arquimeestre da Cidadela**, respondendo às consultas do Pequeno Conselho com base estrita no conhecimento extraído dos pergaminhos oficiais indexados.

---

## 🏛️ Arquitetura do Sistema

```text
[ Cliente / REST Client ]
           │
           ▼
[ Google Cloud Run (Ubuntu Jammy / glibc) ]
           │
           ├─► [ Spring AI ChatClient (Gemini 1.5 Pro) ]
           │
           └─► [ Cloud SQL Proxy / Socket Factory ]
                      │
                      ▼
        [ Cloud SQL: PostgreSQL + PGVector ]
```

### 🛠️ Tech Stack
* **Java 17** & **Spring Boot 3.4**
* **Spring AI (1.0.0-M1)** — Módulo de abstração de LLMs e Vector Stores.
* **Google Vertex AI** — Modelos `gemini-1.5-pro` (Chat) e `text-embedding-004` (Embeddings).
* **Cloud SQL (PostgreSQL + PGVector)** — Banco de dados relacional com suporte a índices vetoriais HNSW e busca por distância cosseno (`COSINE_DISTANCE`).
* **Cloud SQL Socket Factory** — Conexão segura e nativa em nuvem sem exposição de portas públicas.
* **Google Cloud Run** — Runtime Serverless executando contêineres Docker multi-stage baseados em Ubuntu Jammy (prevenindo falhas de biblioteca nativa gRPC/Netty).

---

## 📋 Pré-requisitos

Antes de iniciar, certifique-se de ter instalado em sua máquina:
1. **JDK 17+** e **Maven 3.9+**
2. **Google Cloud CLI (`gcloud`)** autenticado (`gcloud auth login`)
3. **Docker Desktop** (opcional para testes locais)
4. Seu editor de código Java favorito (IntelliJ IDEA, VS Code ou Eclipse)

---

## 🚀 Passo a Passo de Implantação

### 1. Configurar o Ambiente GCP

Abra o seu terminal **PowerShell** (ou Bash) e defina as variáveis base do projeto:

```powershell
$env:PROJECT_ID = "citadel-westeros-gcp"
$env:REGION = "us-central1"
$env:DB_INSTANCE_NAME = "citadel-vault-db"
$env:DB_NAME = "citadel_db"
$env:DB_USER = "maester"
$env:NEW_DB_PASS = "HighValyrianSecret123456!"

# Ativar o projeto na CLI da GCP
gcloud config set project $env:PROJECT_ID

# Habilitar as APIs necessárias na sua conta da GCP
gcloud services enable `
  aiplatform.googleapis.com `
  sqladmin.googleapis.com `
  cloudbuild.googleapis.com `
  run.googleapis.com `
  artifactregistry.googleapis.com
```

---

### 2. Criar a Instância do Banco de Dados Vetorial (Cloud SQL)

```powershell
# 1. Criar a instância PostgreSQL no Cloud SQL
gcloud sql instances create $env:DB_INSTANCE_NAME `
  --database-version=POSTGRES_15 `
  --tier=db-custom-1-3840 `
  --region=$env:REGION

# 2. Criar o Banco de Dados e Usuário
gcloud sql databases create $env:DB_NAME --instance=$env:DB_INSTANCE_NAME
gcloud sql users create $env:DB_USER --instance=$env:DB_INSTANCE_NAME --password=$env:NEW_DB_PASS
```

---

### 3. Estrutura de Código da Aplicação

#### `pom.xml` (Dependências Core)

```xml
<properties>
    <java.version>17</java.version>
    <spring-ai.version>1.0.0-M1</spring-ai.version>
</properties>

<dependencies>
    <!-- Starter Web -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>

    <!-- Spring AI Starters -->
    <dependency>
        <groupId>org.springframework.ai</groupId>
        <artifactId>spring-ai-vertex-ai-gemini-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.ai</groupId>
        <artifactId>spring-ai-pgvector-store-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.ai</groupId>
        <artifactId>spring-ai-pdf-document-reader</artifactId>
    </dependency>

    <!-- Socket Factory nativo do Cloud SQL -->
    <dependency>
        <groupId>com.google.cloud.sql</groupId>
        <artifactId>postgres-socket-factory</artifactId>
        <version>1.15.0</version>
    </dependency>
    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
        <scope>runtime</scope>
    </dependency>
</dependencies>
```

#### `src/main/resources/application.yml`

```yaml
spring:
  application:
    name: citadel-raven-rag
  main:
    allow-bean-definition-overriding: true
  ai:
    vertex:
      ai:
        gemini:
          project-id: ${GCP_PROJECT_ID:citadel-westeros-gcp}
          location: ${GCP_LOCATION:us-central1}
          chat:
            options:
              model: ${GEMINI_MODEL:gemini-1.5-pro}
        embedding:
          project-id: ${GCP_PROJECT_ID:citadel-westeros-gcp}
          location: ${GCP_LOCATION:us-central1}
          text:
            options:
              model: text-embedding-004
    vectorstore:
      pgvector:
        index-type: HNSW
        distance-type: COSINE_DISTANCE
        dimensions: 768
        initialize-schema: true

  datasource:
    url: ${SPRING_DATASOURCE_URL:jdbc:postgresql://localhost:5432/citadel_db}
    username: ${SPRING_DATASOURCE_USERNAME:${DB_USER:maester}}
    password: ${SPRING_DATASOURCE_PASSWORD:${DB_PASS:high_valyrian_secret}}
    driver-class-name: org.postgresql.Driver

server:
  port: 8080
```

---

### 4. Build de Imagem no Cloud Build & Deploy no Cloud Run

#### Compilação e envio ao Artifact Registry
```powershell
# 1. Criar o repositório Docker na GCP
gcloud artifacts repositories create citadel-repo `
  --repository-format=docker `
  --location=$env:REGION

# 2. Compilar e publicar a imagem usando o Cloud Build
gcloud builds submit --tag "$env:REGION-docker.pkg.dev/$env:PROJECT_ID/citadel-repo/citadel-raven:v3" .
```

#### Deploy no Cloud Run com Vinculação Cloud SQL
```powershell
# Obter o nome de conexão nativo do Cloud SQL (project:region:instance)
$CONN_NAME = (gcloud sql instances describe $env:DB_INSTANCE_NAME --format="value(connectionName)")
$JDBC_URL = "jdbc:postgresql:///$($env:DB_NAME)?socketFactory=com.google.cloud.sql.postgres.SocketFactory&cloudSqlInstance=$CONN_NAME"

# Deploy Serverless
gcloud run deploy citadel-raven-service `
  --image "$env:REGION-docker.pkg.dev/$env:PROJECT_ID/citadel-repo/citadel-raven:v3" `
  --platform managed `
  --region $env:REGION `
  --memory 2Gi `
  --cpu 2 `
  --timeout 300 `
  --allow-unauthenticated `
  --add-cloudsql-instances $CONN_NAME `
  --set-env-vars "GCP_PROJECT_ID=$env:PROJECT_ID" `
  --set-env-vars "SPRING_DATASOURCE_URL=$JDBC_URL" `
  --set-env-vars "SPRING_DATASOURCE_USERNAME=$env:DB_USER" `
  --set-env-vars "SPRING_DATASOURCE_PASSWORD=$env:NEW_DB_PASS"
```

---

## 🧪 Validando a Aplicação na Nuvem

Após a conclusão do deploy, utilize a **Service URL** exibida no terminal para testar a aplicação:

```powershell
$URL = "https://citadel-raven-service-xyz.a.run.app"

# 1. Ingestão e Vetorização dos Arquivos da Cidadela (POST)
Invoke-RestMethod -Uri "$URL/api/v1/small-council/ingest" -Method Post

# 2. Consulta Semântica ao Arquimeestre via RAG (GET)
$query = [System.Web.HttpUtility]::UrlEncode("Quem reivindicou o dragão Vermithor?")
Invoke-RestMethod -Uri "$URL/api/v1/small-council/consult-raven?query=$query" -Method Get
```

---

## 🔍 Solução de Problemas Comuns (Troubleshooting)

* **`SIGSEGV` em bibliotecas nativas gRPC/Netty:** Garanta que a imagem de execução no `Dockerfile` utilize distribuição baseada em Debian/Ubuntu (`eclipse-temurin:17-jre-jammy`) e não Alpine, pois o SDK da GCP precisa das bibliotecas de C padrão (`glibc`).
* **Erro de conexão JDBC no Cloud Run:** Verifique se o parâmetro `--add-cloudsql-instances` foi informado com o *Connection Name* exato da instância no comando de deploy do Cloud Run.
* **Enum Invalid Distance Type:** No Spring AI `1.0.0-M1`, a propriedade `distance-type` deve ser configurada como `COSINE_DISTANCE`.

---

## 📜 Licença
Projeto desenvolvido exclusivamente para fins educacionais e workshops técnicos de Java, Spring AI e Google Cloud Platform.