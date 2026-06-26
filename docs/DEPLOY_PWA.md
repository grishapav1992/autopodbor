# Деплой AutoBase PWA на web.carreports.ru

## Что это
Статическая сборка Flutter Web (PWA). Папка `autobase-web/` из архива — это **весь сайт**:
HTML / JS / WASM / ассеты. Для самого PWA **бэкенд/Node не нужен** — достаточно отдавать
статику по HTTPS. API берётся с уже существующего `https://app.carreports.ru`.

## Требования
- **HTTPS обязателен** (Let's Encrypt подойдёт). Без TLS в Safari не работает камера и не
  ставится PWA «на экран Домой».
- HTTP/2 желательно (первая загрузка ~4 МБ движка — с HTTP/2 и сжатием быстрее).
- Размещение в **корне** поддомена `https://web.carreports.ru/` — в сборке `<base href="/">`.
  Если нужно в подпапке (`/app/`), сборку надо пересобрать (см. «Пересборка»).

## Установка
1. Распаковать архив, содержимое `autobase-web/` положить в webroot, напр. `/var/www/autobase-web/`.
2. Завести DNS-запись `web.carreports.ru` и TLS-сертификат.
3. Настроить веб-сервер (пример nginx ниже).

## Пример конфигурации nginx
```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name web.carreports.ru;

    ssl_certificate     /etc/letsencrypt/live/web.carreports.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/web.carreports.ru/privkey.pem;

    root /var/www/autobase-web;
    index index.html;

    # WASM MIME (CanvasKit) — иначе движок грузится медленнее
    types { application/wasm wasm; }

    # Сжатие — заметно ускоряет первую загрузку
    gzip on;
    gzip_types text/plain text/css application/javascript application/json application/wasm image/svg+xml;
    gzip_min_length 1024;
    # brotli ещё лучше, если собран модуль ngx_brotli

    # Статика с контент-хэшами — кэшируем надолго
    location ~* \.(js|wasm|png|jpg|jpeg|svg|woff2?|otf|ttf)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # index.html / service worker / version.json — НЕ кэшировать,
    # иначе клиент не подхватит новую версию после обновления
    location = /index.html              { add_header Cache-Control "no-cache"; }
    location = /flutter_service_worker.js { add_header Cache-Control "no-cache"; }
    location = /version.json            { add_header Cache-Control "no-cache"; }

    # Приложение использует hash-роутинг (#), fallback не обязателен, но не повредит
    location / {
        try_files $uri $uri/ /index.html;
    }
}

# HTTP → HTTPS
server {
    listen 80;
    server_name web.carreports.ru;
    return 301 https://$host$request_uri;
}
```

## CORS — трогать НЕ надо
PWA обращается к API `https://app.carreports.ru`, который уже отдаёт
`Access-Control-Allow-Origin: *`. Кросс-доменные запросы с `web.carreports.ru` работают
без дополнительной настройки (проверено).

## Обновление версии
Новая сборка → заменить содержимое webroot. Благодаря `no-cache` на
`index.html` / `flutter_service_worker.js` клиенты подхватят обновление при следующем заходе.

## Пересборка из исходников (если нужен CI вместо готового архива)
В репозитории проекта:
```bash
flutter build web --release
# результат в build/web/ — это и есть содержимое autobase-web/
# для размещения в подпапке:
flutter build web --release --base-href /app/
```
