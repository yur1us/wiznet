#!/bin/bash

OUTPUT_DIR="PATH_TO_OUT_DIR"
SQL_CRED_FILE="PATH_TO_sql_ipam.gpg"
API_CRED_FILE="PATH_TO_phpipam_api.gpg"
GPG_PASSPHRASE="SOMEPASSWD"

DBHOST="*********"
DBNAME="******"

PHPIPAM_URL="URL_PHPIPAM"

# ===============================
#  Расшифровка SQL логина/пароля
# ===============================
mapfile -t sql_creds < <(
  gpg --quiet --batch --yes \
      --passphrase "$GPG_PASSPHRASE" \
      --decrypt "$SQL_CRED_FILE"
)

DBUSER="${sql_creds[0]}"
DBPASS="${sql_creds[1]}"

# ===============================
#  Расшифровка API token
# ===============================
API_TOKEN=$(gpg --quiet --batch --yes \
      --passphrase "$GPG_PASSPHRASE" \
      --decrypt "$API_CRED_FILE")

# ===============================
#  Получение списка IP из MySQL
# ===============================
mapfile -t IP_ADDRESSES < <(
mysql -u "$DBUSER" -p"$DBPASS" -h "$DBHOST" -D "$DBNAME" -N -e "
SELECT inet_ntoa(ip_addr) AS ip
FROM ipaddresses
WHERE description LIKE '%WIZNET%' AND description LIKE '%VSOL%';
"
)

# ===============================
#  Функция: получить описание по IP
# ===============================
fetch_description() {
    local ip="$1"
    curl -s -X GET \
        -H "token: $API_TOKEN" \
        "${PHPIPAM_URL}${ip}/" |
        jq -r '.data[0].description // "N/A"' |
        sed 's/^ *//;s/ *$//'
}

# ===============================
#  Очистка имени screen/файлов
# ===============================
sanitize_name() {
    echo "$1" | sed 's/[^a-zA-Z0-9._-]/_/g'
}

# ===============================
#  Автоответы на nc вывод
# ===============================
monitor_nc_output() {
    local session="$1"
    local output_file="$2"

    tail -n 20 "$output_file" | while read -r line; do
        case "$line" in
            "Vty connection is timed out."*)
                screen -S "$session" -p 0 -X stuff $'\n'
                ;;
            "Press Return to connect and config this system."*)
                screen -S "$session" -p 0 -X stuff $'\n'
                ;;
            "no cpe is exist"*)
                screen -S "$session" -p 0 -X stuff $'\n'
                ;;
        esac
    done
}

# ===============================
#  Основной цикл по IP
# ===============================

for HOST_IP in "${IP_ADDRESSES[@]}"; do

    # Проверяем доступность
    if ! ping -c 1 -W 2 "$HOST_IP" &>/dev/null; then
        continue
    fi

    # Получаем описание
    DESCRIPTION=$(fetch_description "$HOST_IP")
    [ -z "$DESCRIPTION" ] && DESCRIPTION="$HOST_IP"

    SCREEN_SESSION=$(sanitize_name "$DESCRIPTION")
    OUTPUT_FILE="$OUTPUT_DIR/${SCREEN_SESSION}-out"

    # Создаём screen если нет
    if ! screen -ls | grep -q "$SCREEN_SESSION"; then
        echo "Creating screen session: $SCREEN_SESSION"
        screen -dmS "$SCREEN_SESSION" bash -c "nc $HOST_IP 5000 | tee -a \"$OUTPUT_FILE\""
    fi

    # Запуск мониторинга
    monitor_nc_output "$SCREEN_SESSION" "$OUTPUT_FILE" &
done

wait
