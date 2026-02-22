#!/bin/bash

# =========================================================================
# Script de inicio para Render.com (SilverBullet + Rclone Google Drive)
# =========================================================================

export SPACE="/space"
export RCLONE_CONF="/root/.config/rclone/rclone.conf"

# Validaciones de seguridad
if [ -z "$GDRIVE_CLIENT_ID" ] || [ -z "$GDRIVE_CLIENT_SECRET" ] || [ -z "$GDRIVE_REFRESH_TOKEN" ]; then
  echo "CRITICO: Faltan variables de entorno de Google Drive (Client ID, Secret o Refresh Token). Revisa la configuracion en Render."
  exit 1
fi

echo "1. Obteniendo un Token de Acceso fresco de Google..."
RESPONSE=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d client_id="${GDRIVE_CLIENT_ID}" \
  -d client_secret="${GDRIVE_CLIENT_SECRET}" \
  -d refresh_token="${GDRIVE_REFRESH_TOKEN}" \
  -d grant_type="refresh_token")

ACCESS_TOKEN=$(echo $RESPONSE | jq -r .access_token)

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "CRITICO: No se pudo verificar el Refresh Token con Google."
  echo "Google respondio: $RESPONSE"
  echo "Por favor regenera el Refresh Token usando las herramientas locales."
  exit 1
fi

# Generamos una fecha de expiracion arbitraria en el futuro
# para que Rclone lo detecte como valido y use el access_token actual.
# Cuando expire realmente (~1 hora), Rclone usara el refresh_token para obtener uno nuevo solito.
FUTURE_DATE=$(date -d "+1 hour" -Iseconds 2>/dev/null || date -Iseconds)

echo "2. Configurando Rclone de forma segura..."
mkdir -p /root/.config/rclone
cat <<EOF > ${RCLONE_CONF}
[gdrive]
type = drive
client_id = ${GDRIVE_CLIENT_ID}
client_secret = ${GDRIVE_CLIENT_SECRET}
scope = drive
token = {"access_token":"${ACCESS_TOKEN}","token_type":"Bearer","refresh_token":"${GDRIVE_REFRESH_TOKEN}","expiry":"${FUTURE_DATE}"}
EOF

echo "3. Descargando notas de Google Drive al servidor..."
# Descargamos todo para tener los archivos locales listos
rclone copy gdrive: ${SPACE} --config ${RCLONE_CONF} --include "*.md" --update --verbose

echo "4. Iniciando Sync Ultrarrapido en segundo plano..."
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

echo "5. Arrancando SilverBullet..."
# El binario oficial de Zefhemel esta en el PATH como 'silverbullet'
exec silverbullet ${SPACE} --port 3000
