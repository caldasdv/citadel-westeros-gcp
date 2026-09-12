# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Citadel Raven RAG — a Spring Boot 3.4.5 / Spring AI 1.0.0 (Java 17) RAG demo service themed around Game of Thrones. It ingests a PDF ("Targaryen lineage and dragons") into a PGVector store using Vertex AI embeddings, then answers questions about it via a Gemini-backed `ChatClient` persona ("Arquimeestre da Cidadela"). Built to run on GCP (Cloud Run + Cloud SQL Postgres + Vertex AI).

## Commands

```bash
# Build
mvn clean install -DskipTests

# Run locally (needs a reachable Postgres w/ pgvector and GCP credentials for Vertex AI)
mvn spring-boot:run

# Package (used by Dockerfile)
mvn package -DskipTests

# Docker build
docker build -t citadel-raven-rag .
```

No test sources currently exist in `src/test`.

### Exercising the API

```bash
# Ingest the bundled PDF into the vector store
curl -X POST http://localhost:8080/api/v1/small-council/ingest

# Ask a question against the ingested knowledge
curl -G http://localhost:8080/api/v1/small-council/consult-raven --data-urlencode "query=Quem é o pai de Daenerys?"
```

## Architecture

Three-piece Spring AI RAG pipeline, all under `com.citadel.raven`:

- `config/CitadelVectorConfig` — defines the `VectorStore` bean (`PgVectorStore`, backed by `JdbcTemplate` + the configured `EmbeddingModel`).
- `service/CitadelIngestionService` — reads the classpath PDF (`src/main/resources/citadel-archives/targaryen-lineage-and-dragons.pdf`) with `PagePdfDocumentReader`, splits it via `TokenTextSplitter` (500 tokens/chunk, 100 overlap), and writes the chunks into the `VectorStore` (embeddings generated automatically via Vertex AI on `accept()`).
- `service/GrandMaesterAdvisorService` — builds a `ChatClient` with a fixed system persona and a `QuestionAnswerAdvisor` (topK=3, similarity threshold 0.7) wired to the vector store, so every chat call is RAG-augmented against whatever has been ingested.
- `web/SmallCouncilController` — exposes both as REST endpoints under `/api/v1/small-council` (`POST /ingest`, `GET /consult-raven?query=`).

Config (`src/main/resources/application.yml`) wires:
- Vertex AI Gemini chat model + Vertex AI `text-embedding-004` embeddings, project id from `GCP_PROJECT_ID` (defaults to `citadel-westeros-gcp`), region `us-central1`.
- PGVector store: HNSW index, `COSINE_DISTANCE`, 768 dimensions, schema auto-initialized.
- Datasource from `SPRING_DATASOURCE_URL` / `DB_USER` / `DB_PASS` (defaults point at a local Postgres `citadel_db`).

## GCP Provisioning

`bootstrap.sh` / `bootstrap.ps1` (bash and PowerShell equivalents) provision the GCP project referenced by `application.yml`: enable Cloud Run, Cloud SQL Admin, Vertex AI, and Artifact Registry APIs; create the `citadel-repo` Artifact Registry docker repo; create a Cloud SQL Postgres 15 instance (`citadel-vault-db`) and the `citadel_db` database/`maester` user. These scripts contain a hardcoded demo DB password — treat it as a placeholder, not a real secret, when provisioning for real use.

The `Dockerfile` is a two-stage build (Maven builder → `eclipse-temurin:17-jre-jammy` runtime), runs as a non-root user, and expects `SPRING_DATASOURCE_URL`/`DB_USER`/`DB_PASS`/`GCP_PROJECT_ID` to be supplied as environment variables at deploy time (e.g. via Cloud Run).
