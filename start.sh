#!/bin/bash

# Este script se ejecuta automaticamente cuando Render arranca el servidor

export SPACE="/space"
export RCLONE_CONF="/root/.config/rclone/rclone.conf"

# 1. Crear la configuracion de Rclone de forma SEGURA 
# (usando las variables de entorno de Render, asi no subimos secretos a GitHub)
mkdir -p /root/.config/rclone
cat <<EOF > ${RCLONE_CONF}
[gdrive]
type = drive
client_id = ${GDRIVE_CLIENT_ID}
client_secret = ${GDRIVE_CLIENT_SECRET}
scope = drive
token = {"access_token":"","token_type":"Bearer","refresh_token":"${GDRIVE_REFRESH_TOKEN}","expiry":"2000-01-01T00:00:00.000Z"}
EOF

echo "1. Descargando notas de Google Drive por primera vez..."
rclone copy gdrive: ${SPACE} --config ${RCLONE_CONF} --include "*.md" --update --verbose

echo "2. Iniciando Sync Ultrarrapido en segundo plano..."
(
  RCLONE_FLAGS="--fast-list --transfers 16 --checkers 16 --drive-chunk-size 32M --tpslimit 10 --update --quiet"
  while true; do
    # Bajar cambios
    rclone copy gdrive: ${SPACE} --config ${RCLONE_CONF} --include "*.md" ${RCLONE_FLAGS}
    # Subir cambios
    rclone copy ${SPACE} gdrive: --config ${RCLONE_CONF} --include "*.md" ${RCLONE_FLAGS}
    sleep 2
  done
) &

echo "3. Arrancando SilverBullet..."
# Ejecutamos SilverBullet directamente usando Deno (la imagen base lo incluye)
exec deno run -A --unstable-kv --unstable-worker-options jsr:@silverbulletmd/silverbullet ${SPACE} --port 3000
