# Статика для сторов (privacy + support)

> **Актуальное состояние (2026-07-20, решение Григория).** Страницы
> РАЗВЁРНУТЫ через GitHub Pages из ветки `gh-pages` этого репозитория:
> `https://grishapav1992.github.io/autopodbor/privacy.html` и
> `.../support.html`. Модерация Apple с этими URL пройдена. Тот же адрес
> указан внутри приложения (`_policyUrl` в privacy_policy.dart /
> personal_data_consent.dart). При правке `store/site/*.html` не забыть
> перезалить ветку `gh-pages` (пуш — HTTPS через VPN-прокси, SSH к GitHub
> оборван оператором). Nginx-вариант ниже — опционально, если захочется
> красивый домен `carreports.ru/privacy`; тогда вернуть `_policyUrl`.

Две самодостаточные HTML-страницы без зависимостей — обязательные URL для
App Store Connect (и пригодятся RuStore):

| Файл | Открывается по адресу | Куда вписывается |
|---|---|---|
| `privacy.html` | `https://grishapav1992.github.io/autopodbor/privacy.html` | ASC → App Information → Privacy Policy URL |
| `support.html` | `https://grishapav1992.github.io/autopodbor/support.html` | ASC → страница версии → URL-адрес службы поддержки |

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
