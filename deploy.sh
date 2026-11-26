#!/usr/bin/env bash
# Construye, publica y despliega una version. Si el smoke test falla, vuelve a la anterior.
# Uso: ./deploy.sh [tag]   (sin argumento usa el hash corto del commit)
set -euo pipefail

# Trabajar siempre desde la carpeta del script
cd "$(dirname "$0")"

TAG="${1:-$(git rev-parse --short HEAD)}"
IMAGE="localhost:5000/pagosya-api:$TAG"

echo "== Construyendo $IMAGE"
docker build --build-arg APP_VERSION="$TAG" -t "$IMAGE" app/

echo "== Publicando en el registry local"
docker push "$IMAGE"

echo "== Desplegando $TAG"
TAG="$TAG" docker compose up -d

echo "== Smoke test"
for intento in $(seq 1 30); do
  respuesta="$(curl -fsS --max-time 2 http://localhost:8080/ 2>/dev/null || true)"
  # Debe responder la version recien desplegada, no una anterior
  if [ "$respuesta" = "PagosYA api $TAG" ]; then
    echo "$TAG" > .last-good
    echo "OK $TAG"
    exit 0
  fi
  sleep 0.5
done

echo "smoke fallo con $TAG" >&2
if [ -f .last-good ]; then
  anterior="$(cat .last-good)"
  TAG="$anterior" docker compose up -d
  echo "vuelto a $anterior" >&2
else
  echo "no hay una version buena registrada, no se puede volver atras" >&2
fi
exit 1
