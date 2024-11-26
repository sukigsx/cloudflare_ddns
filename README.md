# cloudflare_ddns
Actualizador dinámico de DNS (DDNS) que utiliza la API de Cloudflare para mantener actualizados los registros DNS de un dominio.

A continuación, se describe su funcionamiento:

Variables de configuración:

Configura credenciales de acceso a Cloudflare (AUTH_EMAIL, AUTH_KEY, etc.), el dominio, subdominios, TTL, y opciones de proxy.
Define los datos para enviar notificaciones a Slack/Discord.
Comprobación periódica de la IP pública:

Obtiene la IP pública actual usando Cloudflare o servicios como api.ipify.org.
Verifica si la IP es válida mediante un regex.
Consulta de registros DNS:

Recorre la lista de subdominios definidos en RECORD_NAMES.
Obtiene el registro DNS tipo A del subdominio usando la API de Cloudflare.
Si el registro no existe, informa el error.
Actualización de registros DNS:

Si la IP pública actual difiere de la IP almacenada en el registro DNS, la actualiza mediante la API de Cloudflare.
Envía notificaciones a Slack o Discord sobre el estado de la actualización.
Bucle infinito:

Repite las comprobaciones y actualizaciones cada cierto tiempo, definido por TIEMPO_COMPROBAR_IPS.
Este script automatiza el mantenimiento de registros DNS para conexiones con IP dinámica.

----------------------------------------------------
DOCKER COMPOSE

Este archivo de Docker Compose configura un servicio para ejecutar el script de actualización dinámica de DNS (DDNS). Explicación:

Servicio ddns-updater:

build: Construye una imagen Docker usando el archivo Dockerfile ubicado en /home/sukigsx/prueba.
container_name: Nombra al contenedor como ddns_updater.
Variables de entorno (environment):

Proporciona credenciales de Cloudflare (AUTH_EMAIL, AUTH_KEY, etc.).
Define los subdominios (RECORD_NAMES) a actualizar, TTL, y opciones como proxy.
Configura el intervalo para verificar la IP (TIEMPO_COMPROBAR_IPS) y parámetros de notificación.
restart: always: Asegura que el contenedor se reinicie automáticamente si falla.

Este servicio automatiza el despliegue del actualizador DDNS en un contenedor Docker.
