#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$REPO_DIR/.runtime"
PID_FILE="$RUNTIME_DIR/application.pid"
APP_JAR="$REPO_DIR/target/citadel-raven-rag-1.0.0-SNAPSHOT.jar"

if [[ -f "$PID_FILE" ]]; then
    APP_PID="$(tr -d '[:space:]' < "$PID_FILE")"
    APP_COMMAND=""

    if [[ "$APP_PID" =~ ^[0-9]+$ ]]; then
        APP_COMMAND="$(ps -p "$APP_PID" -o command= 2>/dev/null || true)"
    fi

    if [[ "$APP_PID" =~ ^[0-9]+$ ]] && [[ "$APP_COMMAND" == *"$APP_JAR"* ]]; then
        echo "Encerrando Spring Boot (PID $APP_PID)..."
        kill "$APP_PID"

        for ((attempt = 1; attempt <= 30; attempt++)); do
            if ! kill -0 "$APP_PID" 2>/dev/null; then
                break
            fi
            sleep 1
        done

        if kill -0 "$APP_PID" 2>/dev/null; then
            echo "A aplicação não encerrou no prazo; forçando o processo $APP_PID."
            kill -9 "$APP_PID"
        fi
    elif [[ -n "$APP_COMMAND" ]]; then
        echo "Aviso: o PID $APP_PID não pertence à aplicação deste projeto; ele não será encerrado."
    else
        echo "A aplicação já estava parada."
    fi

    rm -f "$PID_FILE"
else
    echo "Nenhum PID da aplicação foi registrado."
    PORT_PID="$(lsof -tiTCP:8080 -sTCP:LISTEN | head -n 1 || true)"
    if [[ -n "$PORT_PID" ]]; then
        echo "Aviso: a porta 8080 está sendo usada pelo PID $PORT_PID, iniciado fora deste script; ele não será encerrado."
    fi
fi

if docker info >/dev/null 2>&1; then
    echo "Parando PostgreSQL/pgvector sem apagar os dados..."
    docker compose -f "$REPO_DIR/compose.yaml" down
else
    echo "Docker Desktop não está disponível; nenhum container foi alterado."
fi

echo "Parando o serviço Ollama..."
brew services stop ollama >/dev/null

echo "Pilha local parada. O volume do PostgreSQL e os modelos do Ollama foram preservados."
