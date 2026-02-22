# Usamos Deno oficial basado en Alpine Linux (muy ligero)
FROM denoland/deno:alpine

# Movernos a usuario root temporalmente para instalar cosas
USER root

# Instalamos rclone, bash y tini (ayuda a que los scripts en Docker corten bien)
RUN apk update && apk add --no-cache rclone bash tini

# Creamos la carpeta /space que SilverBullet va a leer
RUN mkdir -p /space && chown -R deno:deno /space

# Copiamos nuestro script maestro
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Render espera que escuchemos normalmente en el puerto 3000 o 10000
EXPOSE 3000

# Arrancamos con Tini para que los procesos de fondo (como rclone) no queden congelados
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/start.sh"]
