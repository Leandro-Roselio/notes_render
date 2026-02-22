# Usamos la imagen oficial de SilverBullet como base (que ya incluye el binario y configuracion de Deno)
FROM zefhemel/silverbullet:latest

# Movernos a usuario root temporalmente para instalar cosas
USER root

# Instalamos rclone, bash, curl y jq (herramientas para el script de sincronizacion)
RUN apk update && apk add --no-cache rclone bash curl jq

# Creamos la carpeta /space
RUN mkdir -p /space

# Copiamos nuestro script maestro
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Render espera que escuchemos normalmente en el puerto 3000
EXPOSE 3000

# Usamos nuestro script de sincronizacion
# (El binario de SilverBullet se llama desde adentro del script)
ENTRYPOINT ["/start.sh"]
