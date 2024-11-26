#!/bin/bash
## change to "bin/sh" when necessary

auth_email="${AUTH_EMAIL}"                                          # The email used to login 'https://dash.cloudflare.com'
auth_method="${AUTH_METHOD}"                                        # Set to "global" for Global API Key or "token" for Scoped API Token
auth_key="${AUTH_KEY}"                                              # Your API Token or Global API Key
zone_identifier="${ZONE_IDENTIFIER}"                                # Can be found in the "Overview" tab of your domain
IFS=' ' read -r -a record_names <<< "$RECORD_NAMES"                  # Lista de subdominios que quieres actualizar
ttl="${TTL}"                                                        # Set the DNS TTL (seconds) - now a number
proxy="${PROXY}"                                                    # Set the proxy to true or false
sitename="${SITENAME}"                                               # Title of site "Example Site"
slackchannel="${SLACKCHANNEL}"                                       # Slack Channel #example
slackuri="${SLACKURI}"                                               # URI for Slack WebHook "https://hooks.slack.com/services/xxxxx"
discorduri="${DISCORDURI}"                                           # URI for Discord WebHook "https://discordapp.com/api/webhooks/xxxxx"
tiempo_comprobar_ips="${TIEMPO_COMPROBAR_IPS}"                       # Tiempo en segundos para esperar antes de comprobar la IP nuevamente (ej. 3600 = 1 hora)

###########################################
## Bucle infinito para comprobar cada cierto tiempo
###########################################
while true; do
    ###########################################
    ## Comprobar IP pública
    ###########################################
    ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
    ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
    if [[ ! $ret == 0 ]]; then
        # En caso de que cloudflare no retorne una IP válida.
        ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
    else
        # Extraer solo la IP de la línea 'ip' de Cloudflare.
        ip=$(echo $ip | sed -E "s/^ip=($ipv4_regex)$/\1/")
    fi

    # Usar regex para verificar si la IP es válida
    if [[ ! $ip =~ ^$ipv4_regex$ ]]; then
        logger -s "DDNS Updater: Failed to find a valid IP."
        exit 2
    fi

    ###########################################
    ## Comprobar y configurar el encabezado de autenticación
    ###########################################
    if [[ "${auth_method}" == "global" ]]; then
      auth_header="X-Auth-Key:"
    else
      auth_header="Authorization: Bearer"
    fi

    ###########################################
    ## Recorrer la lista de subdominios
    ###########################################

    for record_name in "${record_names[@]}"; do
        logger "DDNS Updater: Check Initiated for $record_name"
        
        # Buscar el registro A del subdominio
        record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=A&name=$record_name" \
                          -H "X-Auth-Email: $auth_email" \
                          -H "$auth_header $auth_key" \
                          -H "Content-Type: application/json")

        ###########################################
        ## Comprobar si el subdominio tiene un registro A
        ###########################################
        if [[ $record == *"\"count\":0"* ]]; then
            logger -s "DDNS Updater: Record for $record_name does not exist, perhaps create one first? (${ip} for ${record_name})"
            continue
        fi

        ###########################################
        ## Obtener la IP existente
        ###########################################
        old_ip=$(echo "$record" | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
        # Comparar si son la misma
        if [[ $ip == $old_ip ]]; then
            logger "DDNS Updater: IP ($ip) for $record_name has not changed."
            continue
        fi

        ###########################################
        ## Obtener el identificador del registro
        ###########################################
        record_identifier=$(echo "$record" | sed -E 's/.*"id":"(\w+)".*/\1/')

        ###########################################
        ## Cambiar la IP en Cloudflare usando la API
        ###########################################
        update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
                             -H "X-Auth-Email: $auth_email" \
                             -H "$auth_header $auth_key" \
                             -H "Content-Type: application/json" \
                             --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":$ttl,\"proxied\":${proxy}}")

        ###########################################
        ## Reportar el estado
        ###########################################
        case "$update" in
        *"\"success\":false"*)
            echo -e "DDNS Updater: $ip $record_name DDNS failed for $record_identifier ($ip). DUMPING RESULTS:\n$update" | logger -s 
            if [[ $slackuri != "" ]]; then
                curl -L -X POST $slackuri \
                --data-raw '{
                  "channel": "'$slackchannel'",
                  "text" : "'"$sitename"' DDNS Update Failed: '$record_name': '$record_identifier' ('$ip')."
                }'
            fi
            if [[ $discorduri != "" ]]; then
                curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST \
                --data-raw '{
                  "content" : "'"$sitename"' DDNS Update Failed: '$record_name': '$record_identifier' ('$ip')."
                }' $discorduri
            fi
            continue;;
        *)
            logger "DDNS Updater: $ip $record_name DDNS updated."
            if [[ $slackuri != "" ]]; then
                curl -L -X POST $slackuri \
                --data-raw '{
                  "channel": "'$slackchannel'",
                  "text" : "'"$sitename"' Updated: '$record_name''"'"'s'""' new IP Address is '$ip'"
                }'
            fi
            if [[ $discorduri != "" ]]; then
                curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST \
                --data-raw '{
                  "content" : "'"$sitename"' Updated: '$record_name''"'"'s'""' new IP Address is '$ip'"
                }' $discorduri
            fi
            ;;
        esac
    done

    ###########################################
    ## Esperar antes de la siguiente comprobación
    ###########################################
    sleep "$tiempo_comprobar_ips"
done
