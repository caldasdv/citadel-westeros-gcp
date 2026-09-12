#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$REPO_DIR/.runtime"
PID_FILE="$RUNTIME_DIR/application.pid"
LOG_FILE="$RUNTIME_DIR/application.log"
APP_JAR="$REPO_DIR/target/citadel-raven-rag-1.0.0-SNAPSHOT.jar"

cd "$REPO_DIR"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Erro: '$1' não está instalado ou não está no PATH."
        exit 1
    fi
}

wait_for_command() {
    local description="$1"
    local attempts="$2"
    shift 2

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if "$@" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    echo "Erro: $description não ficou disponível dentro do tempo esperado."
    return 1
}

ensure_model() {
    local model="$1"

    if ollama list | awk 'NR > 1 {print $1}' | grep -Fqx "$model"; then
        echo "Modelo disponível: $model"
    else
        echo "Baixando modelo local: $model"
        ollama pull "$model"
    fi
}

require_command brew
require_command curl
require_command docker
require_command lsof
require_command mise
require_command ollama

mkdir -p "$RUNTIME_DIR"

if [[ -f "$PID_FILE" ]]; then
    EXISTING_PID="$(tr -d '[:space:]' < "$PID_FILE")"
    if [[ "$EXISTING_PID" =~ ^[0-9]+$ ]] && kill -0 "$EXISTING_PID" 2>/dev/null; then
        echo "A aplicação já está rodando (PID $EXISTING_PID)."
        echo "Log: $LOG_FILE"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

PORT_PID="$(lsof -tiTCP:8080 -sTCP:LISTEN | head -n 1 || true)"
if [[ -n "$PORT_PID" ]]; then
    echo "Erro: a porta 8080 já está em uso pelo PID $PORT_PID."
    echo "Encerre esse processo ou use scripts/stop-local.sh se ele pertencer ao projeto."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Iniciando Docker Desktop..."
    open -a Docker
    wait_for_command "Docker Desktop" 60 docker info
fi

echo "Subindo PostgreSQL com pgvector..."
docker compose -f "$REPO_DIR/compose.yaml" up -d --wait

if ! curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "Iniciando Ollama..."
    brew services start ollama
    wait_for_command "Ollama" 30 curl -fsS http://127.0.0.1:11434/api/tags
fi

ensure_model "llama3.2:3b"
ensure_model "embeddinggemma:latest"

echo "Compilando a aplicação com Java 17..."
(
    cd "$REPO_DIR"
    mise exec -- mvn -q package -DskipTests
)

echo "Iniciando Spring Boot..."
nohup mise exec -- java -jar "$APP_JAR" >"$LOG_FILE" 2>&1 &
APP_PID=$!
echo "$APP_PID" > "$PID_FILE"

for ((attempt = 1; attempt <= 60; attempt++)); do
    if ! kill -0 "$APP_PID" 2>/dev/null; then
        echo "Erro: a aplicação encerrou durante a inicialização."
        tail -n 80 "$LOG_FILE"
        rm -f "$PID_FILE"
        exit 1
    fi

    HTTP_STATUS="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/ || true)"
    if [[ "$HTTP_STATUS" =~ ^[1-5][0-9][0-9]$ ]]; then
        echo "Pilha local pronta."
        echo "API: http://localhost:8080"
        echo "PID da aplicação: $APP_PID"
        echo "Log: $LOG_FILE"
        exit 0
    fi
    sleep 1
done

echo "Erro: a aplicação não respondeu na porta 8080 dentro do tempo esperado."
tail -n 80 "$LOG_FILE"
kill "$APP_PID" 2>/dev/null || true
rm -f "$PID_FILE"
exit 1
