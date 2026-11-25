#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:?Uso: $0 tu-dominio.com correo@ejemplo.com}"
CORREO="${2:?Uso: $0 tu-dominio.com correo@ejemplo.com}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$RAIZ/certs/letsencrypt"

docker compose -f "$RAIZ/docker-compose.yml" stop balanceador || true

docker run --rm -p 80:80 \
  -v "$RAIZ/certs/letsencrypt:/etc/letsencrypt" \
  certbot/certbot certonly --standalone \
  -d "$DOMAIN" --email "$CORREO" --agree-tos --no-eff-email --non-interactive

cp -L "$RAIZ/certs/letsencrypt/live/$DOMAIN/fullchain.pem" "$RAIZ/certs/fullchain.pem"
cp -L "$RAIZ/certs/letsencrypt/live/$DOMAIN/privkey.pem" "$RAIZ/certs/privkey.pem"
chmod 600 "$RAIZ/certs/privkey.pem"

docker compose -f "$RAIZ/docker-compose.yml" up -d balanceador
echo "Certificado de Let's Encrypt instalado para $DOMAIN"
