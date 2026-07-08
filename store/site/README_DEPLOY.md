# Статика carreports.ru для сторов (privacy + support)

Две самодостаточные HTML-страницы без зависимостей — обязательные URL для
App Store Connect (и пригодятся RuStore):

| Файл | Должен открываться по адресу | Куда вписывается |
|---|---|---|
| `privacy.html` | `https://carreports.ru/privacy` | ASC → App Information → Privacy Policy URL |
| `support.html` | `https://carreports.ru/support` | ASC → страница версии → URL-адрес службы поддержки |

Адрес `https://carreports.ru/privacy` уже указан ВНУТРИ приложения как
официальный адрес политики (lib/ui/mobile/screens/profile_screens/privacy_policy.dart,
`_policyUrl`) — то есть домен и путь менять нельзя, нужно просто поднять.

## Задача для дева (5 минут)

На сервере, где уже крутится nginx для app.carreports.ru, добавить сайт для
корневого домена carreports.ru:

```nginx
server {
    listen 443 ssl;
    server_name carreports.ru;
    # ssl_certificate / ssl_certificate_key — тот же wildcard/SAN серт,
    # что и для app.carreports.ru (Let's Encrypt покрывает carreports.ru?
    # если нет — выпустить: certbot --nginx -d carreports.ru)

    root /var/www/carreports;

    location = /privacy { default_type text/html; try_files /privacy.html =404; }
    location = /support { default_type text/html; try_files /support.html =404; }
    # корень пока может отдавать support или заглушку:
    location = / { return 302 /support; }
}
```

Файлы `privacy.html` и `support.html` положить в `/var/www/carreports/`.

## Проверка перед отправкой в ревью

```bash
curl -sI https://carreports.ru/privacy | head -1   # HTTP/2 200
curl -sI https://carreports.ru/support | head -1   # HTTP/2 200
```

Apple открывает оба URL при проверке — они должны отдавать 200 ДО нажатия
«Отправить на проверку».
