#!/usr/bin/env bash
# Executado NA VPS pelo GitHub Actions. Mexe só no projeto compose "fuseagencia".
set -euo pipefail

APP_DIR="${APP_DIR:-/root/fuseagencia/deploy}"
: "${FUSEAGENCIA_WEB_IMAGE:?imagem não informada}"
PORT=3700

cd "$APP_DIR"

case "$FUSEAGENCIA_WEB_IMAGE" in
  *@sha256:*) ;;
  *) echo "ERRO: imagem sem digest: $FUSEAGENCIA_WEB_IMAGE"; exit 1 ;;
esac

# Guarda a versão anterior para rollback manual.
[ -f images.env ] && cp images.env images.env.previous
printf 'FUSEAGENCIA_WEB_IMAGE=%s\n' "$FUSEAGENCIA_WEB_IMAGE" > images.env

docker compose --env-file images.env pull
docker compose --env-file images.env up -d --remove-orphans

echo "Aguardando o site responder em 127.0.0.1:$PORT..."
for i in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://127.0.0.1:$PORT/healthz" >/dev/null \
     && curl -fsS --max-time 3 "http://127.0.0.1:$PORT/" | grep -q "FUSE AGENCIA LTDA"; then
    echo "OK: fuseagencia-web no ar ($FUSEAGENCIA_WEB_IMAGE)"
    exit 0
  fi
  sleep 2
done

echo "ERRO: o site não respondeu. Logs:"
docker compose --env-file images.env logs --tail 50 web || true
if [ -f images.env.previous ]; then
  echo "Voltando para a versão anterior..."
  cp images.env.previous images.env
  docker compose --env-file images.env up -d
fi
exit 1
