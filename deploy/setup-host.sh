#!/usr/bin/env bash
# Executado NA VPS, uma vez, pelo workflow manual "Configurar nginx do host e HTTPS".
# Instala o site no nginx do host e emite o certificado Let's Encrypt via certbot.
# Não toca nos sites das outras aplicações; aborta se o nginx -t falhar.
set -euo pipefail

APP_DIR="${APP_DIR:-/root/fuseagencia/deploy}"
CONF=fuseagencia.com.br.conf
AVAIL=/etc/nginx/sites-available/$CONF
ENABLED=/etc/nginx/sites-enabled/$CONF
VPS_IP=72.60.10.112

for host in fuseagencia.com.br www.fuseagencia.com.br; do
  ip=$(getent ahostsv4 "$host" | awk '{print $1}' | head -1 || true)
  [ "$ip" = "$VPS_IP" ] || { echo "ERRO: $host aponta para '${ip:-nada}', não para $VPS_IP. Ajuste o DNS antes."; exit 1; }
done

if [ -f "$AVAIL" ] && grep -q "managed by Certbot" "$AVAIL"; then
  echo "Site já configurado com HTTPS; só renovando/conferindo o certificado."
else
  install -m 644 "$APP_DIR/host-nginx/$CONF" "$AVAIL"
  ln -sf "$AVAIL" "$ENABLED"
  if ! nginx -t; then
    echo "ERRO: configuração inválida; removendo o site novo."
    rm -f "$ENABLED"
    exit 1
  fi
  systemctl reload nginx
fi

certbot --nginx --non-interactive --agree-tos --redirect --keep-until-expiring \
  --cert-name fuseagencia.com.br -d fuseagencia.com.br -d www.fuseagencia.com.br

nginx -t && systemctl reload nginx
echo "OK: https://fuseagencia.com.br configurado."
