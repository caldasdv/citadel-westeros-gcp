# CLAUDE.md

This file provides guidance to coding agents working in this repository.

## Project overview

Citadel Raven RAG is a local-first Spring Boot 3.4.5 / Spring AI 1.0.0 application on Java 17. It ingests a bundled Game of Thrones-themed PDF, stores local embeddings in PostgreSQL with pgvector, and answers questions through a local Ollama chat model.

The supported development environment is macOS on Apple Silicon, validated on an M1 Pro with 16 GB RAM:

- Java 17 is selected per repository by `mise.toml`.
- The Spring Boot application runs natively on the Mac.
- Ollama runs natively as a Homebrew service for Apple Silicon acceleration.
- Only PostgreSQL 16 with pgvector runs in Docker Desktop.
- No GCP credentials or cloud AI provider are required.

## Runtime services

| Service | Runtime | Address/model |
| --- | --- | --- |
| Application | macOS host | `http://localhost:8080` |
| Ollama chat | macOS host | `llama3.2:3b` |
| Ollama embeddings | macOS host | `embeddinggemma`, 768 dimensions |
| PostgreSQL/pgvector | Docker | `127.0.0.1:5432`, database `citadel_db` |

Keep PostgreSQL and Ollama bound to localhost. Do not add a cloud fallback without an explicit request because the project is intended for private document testing.

## Commands

```bash
# Install/select the repository Java version
mise install

# Start Ollama and ensure both models exist
brew services start ollama
ollama pull llama3.2:3b
ollama pull embeddinggemma

# Start and inspect PostgreSQL
docker compose up -d
docker compose ps

# Build and test
mise exec -- mvn test

# Run the application natively
mise exec -- mvn spring-boot:run

# Or manage the complete local stack in the background
./scripts/start-local.sh
./scripts/stop-local.sh
```

There are currently no test sources under `src/test`; `mvn test` still validates dependency resolution and compilation.

## Exercising the API

```bash
# Ingest the bundled PDF before querying
curl -X POST http://localhost:8080/api/v1/small-council/ingest

# Query knowledge that is present in the PDF
curl -G http://localhost:8080/api/v1/small-council/consult-raven \
  --data-urlencode "query=Quem reivindicou o dragão Vermithor?"
```

Repeated ingestion creates duplicate vector rows. Ingest once unless duplicate handling is being tested.

## Architecture

The RAG pipeline lives under `com.citadel.raven`:

- `service/CitadelIngestionService` reads the classpath PDF with `PagePdfDocumentReader`, splits it with `TokenTextSplitter` (500-token chunks, 100-token overlap), and writes it to the auto-configured `VectorStore`. `embeddinggemma` generates embeddings through the local Ollama API.
- `service/GrandMaesterAdvisorService` creates the `ChatClient` persona and a `QuestionAnswerAdvisor` using `topK=3` and similarity threshold `0.50`. This threshold was measured for `embeddinggemma`; reevaluate it if the embedding model changes.
- `web/SmallCouncilController` exposes `POST /ingest` and `GET /consult-raven?query=` under `/api/v1/small-council`.
- Spring AI's pgvector auto-configuration creates the `VectorStore`; do not add a second manual `VectorStore` bean.

`src/main/resources/application.yml` configures:

- Ollama at `http://localhost:11434`.
- `llama3.2:3b` for chat with a 4096-token context.
- `embeddinggemma` for 768-dimensional embeddings.
- PGVector with HNSW and cosine distance, with schema initialization enabled.
- Local PostgreSQL credentials matching `compose.yaml`.

## Data lifecycle

Changing embedding models requires deleting/recreating existing vectors and ingesting documents again. `docker compose down` preserves the database volume. `docker compose down -v` permanently removes the local database volume and must only be used when a reset is intended.

## Legacy cloud files

`bootstrap.sh` and `bootstrap.ps1` belong to the previous GCP deployment and are not part of the current local workflow. The existing `Dockerfile` can package the application, but normal Mac development runs the JVM on the host so it can reach the host-native Ollama service directly.
