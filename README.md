Создай обычный текстовый файл с токеном

Например:
echo "111YOURAPITOKEN111" > /root/scripts/phpipam_api

Файл должен содержать только токен, без кавычек:
111YOURAPITOKEN111

Зашифруй файл через GPG
Используй тот же метод, что и для sql_ipam.gpg:
gpg -c /root/scripts/phpipam_api

Он спросит пароль → введи ЖЕЛАЕМЫЙ ПАРОЛЬ

После этого появится файл:
/root/scripts/phpipam_api.gpg

Удали исходный незашифрованный файл
shred -u /root/scripts/nexus/phpipam_api

Проверка, что файл расшифровывается

gpg --quiet --batch --yes \
  --passphrase "ЖЕЛАЕМЫЙ ПАРОЛЬ" \
  --decrypt /root/scripts//phpipam_api.gpg
