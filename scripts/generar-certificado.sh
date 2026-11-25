#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-localhost}"
DESTINO="$(cd "$(dirname "$0")/.." && pwd)/certs"

mkdir -p "$DESTINO"

openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout "$DESTINO/privkey.pem" \
  -out "$DESTINO/fullchain.pem" \
  -subj "/CN=$DOMAIN" \
  -addext "subjectAltName=DNS:$DOMAIN,DNS:localhost,IP:127.0.0.1"

chmod 600 "$DESTINO/privkey.pem"
echo "Certificado autofirmado generado para $DOMAIN en $DESTINO"
