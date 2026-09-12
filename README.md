# Citadel Raven RAG — local e privado

Aplicação RAG em Java 17, Spring Boot 3.4 e Spring AI 1.0. O chat, os embeddings e o banco vetorial rodam localmente; documentos e perguntas não são enviados para provedores de IA na nuvem.

## Arquitetura

```text
Cliente HTTP
    |
Spring Boot (host, porta 8080)
    |-- Ollama: llama3.2:3b (chat)
    |-- Ollama: embeddinggemma (embeddings de 768 dimensões)
    `-- PostgreSQL 16 + pgvector (Docker, porta local 5432)
```

O PostgreSQL fica acessível apenas em `127.0.0.1`. O Ollama também deve permanecer na interface local padrão.

## Pré-requisitos

- Docker Desktop
- Homebrew
- `mise` (o `mise.toml` instala/seleciona Java 17)
- Maven 3.9+

## Preparação inicial

Instale o Java configurado para o repositório:

```bash
mise install
```

Instale e inicie o Ollama:

```bash
brew install ollama
brew services start ollama
```

Baixe os dois modelos locais:

```bash
ollama pull llama3.2:3b
ollama pull embeddinggemma
```

## Executar

Com o Docker Desktop aberto, inicie o banco:

```bash
docker compose up -d
```

Confira se o banco ficou saudável:

```bash
docker compose ps
```

Inicie a aplicação no host para o Ollama usar a aceleração do Apple Silicon:

```bash
mise exec -- mvn spring-boot:run
```

Na primeira inicialização, o Spring AI cria a extensão e a tabela vetorial automaticamente.

## Usar a API

Faça a ingestão do PDF incluído no projeto:

```bash
curl -X POST http://localhost:8080/api/v1/small-council/ingest
```

Faça uma pergunta:

```bash
curl -G http://localhost:8080/api/v1/small-council/consult-raven \
  --data-urlencode "query=Quem é o pai de Daenerys?"
```

## Configuração

Os valores padrão estão em `src/main/resources/application.yml`. Eles podem ser sobrescritos por variáveis de ambiente:

| Variável | Padrão |
| --- | --- |
| `OLLAMA_BASE_URL` | `http://localhost:11434` |
| `OLLAMA_CHAT_MODEL` | `llama3.2:3b` |
| `OLLAMA_EMBEDDING_MODEL` | `embeddinggemma` |
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://localhost:5432/citadel_db` |
| `SPRING_DATASOURCE_USERNAME` | `maester` |
| `SPRING_DATASOURCE_PASSWORD` | `high_valyrian_secret` |

Para usar outra senha local, defina `DB_PASS` tanto ao subir o Compose quanto ao executar a aplicação.

Ao trocar o modelo de embeddings, remova os vetores existentes e faça a ingestão novamente. `docker compose down -v` também apaga permanentemente todo o volume local do banco; use apenas quando quiser recomeçar do zero.

## Parar os serviços

```bash
docker compose down
brew services stop ollama
```
