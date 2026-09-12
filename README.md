# Citadel Raven RAG — local e privado

Aplicação RAG em Java 17, Spring Boot 3.4 e Spring AI 1.0. O chat, os embeddings e o banco vetorial rodam localmente; documentos e perguntas não são enviados para provedores de IA na nuvem.

O ambiente principal é **macOS em Apple Silicon**, validado em um MacBook Pro com chip M1 Pro e 16 GB de memória. O Ollama e a aplicação Java rodam nativamente para aproveitar a aceleração do Mac; apenas o PostgreSQL roda no Docker.

## Arquitetura

```text
Cliente HTTP
    |
Spring Boot (host, porta 8080)
    |-- Ollama: llama3.2:3b (chat)
    |-- Ollama: embeddinggemma (embeddings de 768 dimensões)
    `-- PostgreSQL 16 + pgvector (Docker, porta local 5432)
```

O PostgreSQL fica acessível apenas em `127.0.0.1:5432`. O Ollama usa a interface local padrão `127.0.0.1:11434`.

## Pré-requisitos

- macOS em Apple Silicon
- Homebrew
- Docker Desktop para Mac
- `mise` para selecionar o Java 17 deste repositório
- Maven 3.9 ou superior

Versões validadas no ambiente atual:

| Componente | Versão/configuração |
| --- | --- |
| Mac | Apple M1 Pro, 16 GB |
| Java | OpenJDK 17.0.2 via `mise` |
| Maven | 3.9.16 |
| Ollama | 0.33.3 nativo via Homebrew |
| Docker CLI | 29.7.2 |
| Banco | PostgreSQL 16 + pgvector 0.8.6 |

## Preparação inicial

Instale as ferramentas caso ainda não estejam disponíveis:

```bash
brew install mise ollama
```

O arquivo `mise.toml` fixa o Java 17 apenas neste repositório. Instale a versão configurada:

```bash
mise install
```

Inicie o Ollama como serviço do macOS:

```bash
brew services start ollama
```

Baixe os dois modelos locais:

```bash
ollama pull llama3.2:3b
ollama pull embeddinggemma
```

Confirme o serviço e os modelos:

```bash
brew services list
ollama list
```

## Executar

### Inicialização automática

O caminho recomendado sobe o Docker Desktop quando necessário, PostgreSQL/pgvector, Ollama, os modelos e a aplicação Spring Boot:

```bash
./scripts/start-local.sh
```

A aplicação roda em background. A saída fica em `.runtime/application.log`.

Para parar a aplicação, o container do banco e o serviço Ollama sem apagar dados ou modelos:

```bash
./scripts/stop-local.sh
```

O script não fecha o Docker Desktop, pois ele pode estar executando outros projetos.

### Inicialização manual

Abra o Docker Desktop e aguarde o engine ficar disponível. Em seguida, inicie o banco:

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

Na primeira inicialização, o Spring AI habilita a extensão `vector` e cria a tabela `vector_store` automaticamente. Nenhuma credencial GCP é necessária.

## Usar a API

Faça a ingestão do PDF incluído no projeto:

```bash
curl -X POST http://localhost:8080/api/v1/small-council/ingest
```

Faça uma pergunta presente no documento:

```bash
curl -G http://localhost:8080/api/v1/small-council/consult-raven \
  --data-urlencode "query=Quem reivindicou o dragão Vermithor?"
```

Resposta esperada: Vermithor foi reivindicado por Hugh Hammer.

### Bruno

No Bruno, use **Import cURL** e importe as duas chamadas acima. Execute primeiro `POST /ingest` e depois `GET /consult-raven`.

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

O armazenamento vetorial usa HNSW, distância cosseno e 768 dimensões. A busca RAG usa limite de similaridade `0.50`, calibrado para o `embeddinggemma`. Ao trocar o modelo de embeddings, remova os vetores existentes e faça a ingestão novamente.

## Privacidade local

- Perguntas, respostas, fragmentos e embeddings são processados na máquina.
- O acesso à internet é necessário apenas para instalar dependências e baixar imagens ou modelos.
- Não exponha as portas `5432` e `11434` para a rede.
- Não configure modelos cloud do Ollama se o objetivo for manter a inferência local.

## Solução de problemas

### Ollama não responde

```bash
brew services restart ollama
curl http://127.0.0.1:11434/api/tags
```

### Banco não está saudável

```bash
docker compose ps
docker compose logs postgres
```

### O RAG responde que os pergaminhos silenciam

Faça primeiro o `POST /ingest`. Se o modelo de embeddings tiver sido alterado, recrie os vetores e ingira o documento novamente.

Para recomeçar com um banco vazio, `docker compose down -v` apaga permanentemente o volume local; use somente quando realmente quiser excluir os dados.

## Parar os serviços

```bash
docker compose down
brew services stop ollama
```

Os arquivos `bootstrap.sh` e `bootstrap.ps1` são legados da versão GCP e não participam do fluxo local. O `Dockerfile` também não é necessário para o desenvolvimento no Mac; a aplicação é executada no host.
