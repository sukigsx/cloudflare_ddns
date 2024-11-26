# Usar la imagen oficial de Alpine para contener el script
FROM alpine:latest

# Instalar las dependencias necesarias (curl, bash)
RUN apk add --no-cache bash curl

# Copiar el script al contenedor
COPY ddns_updater.sh /usr/local/bin/ddns_updater.sh

# Darle permisos de ejecución al script
RUN chmod +x /usr/local/bin/ddns_updater.sh

# Definir el comando de ejecución cuando el contenedor se inicie
CMD ["/usr/local/bin/ddns_updater.sh"]
