# Запросы к backend-team

Документ собирает API-расширения, нужные фронту для довода флоу
«Заявки от компании» (новый раздел) и догрейда старых задач.

Состояние на **2026-05-21**.

---

## Уже сделано ✅

| Метод | Статус | Закрыло |
|---|---|---|
| `Storage.GetSpecialists({page, limit, search?, cities?, minRating?})` | live | Поиск специалиста по телефону/email (search exact-match) |
| `Storage.GetCompanySpecialists({page, limit})` | live | Список штатных специалистов компании |
| `Storage.UnlinkCompanySpecialist({specialistId})` | live | Удаление сотрудника из штата компании |
| `Storage.CreateRequest({assignedSpecialistId, ...})` | live | Назначение заявки на специалиста при создании |
| `Storage.CreateRequest({note})` + `Storage.GetRequest.note` | live | Заметка компании к заявке |
| `Storage.AcceptRequest / RejectRequest / AbandonRequest / CompleteRequest` | live | Lifecycle заявки |
| `Storage.GetRequest.assignedSpecialist/assignedSpecialistId` | live | Компания видит назначенного специалиста в detail-screen |
| `Storage.GetRequest.reportId/reportNumber` | live | Компания может создать share-ссылку готового отчёта из detail-screen |
| `Storage.AssignSpecialist` | live | Переназначение специалиста на заявку в `created` / `await_payment` |
| `Storage.CancelRequest` | live | Отмена заявки до оплаты/начала работы |
| `GetProfile.isVerifyEmail` | live | Подтверждено 2026-05-20 — флаг приходит в ответе (закрывает бывший P2) |
| `Storage.GetProfile.companyId` + `Storage.GetCompanyProfile({companyId})` | live | Профиль специалиста показывает компанию, в штате которой он состоит |

`RejectRequest` используется специалистом только до взятия заявки в работу.
Если заявка уже оплачена/в работе (`paid_escrow` / `in_work`) и специалист
не может её выполнить, фронт вызывает `Storage.AbandonRequest({requestId, note})`;
`note` обязателен, итоговый статус заявки — `failed`.

---

## Нужно от backend (приоритет ↓)

### 🔴 P0 ИНЦИДЕНТ (2026-07-05): AiQueue не достукивается до провайдера codex.sale — все AI-функции лежат

**Симптом в приложении** (включая прод-билд RuStore 1.0.0+3): любая
AI-кнопка (сверка документов, тест-драйв, комментарий по материалам,
сводка, VIN-параметры) → «AI вернул пустой ответ»; в редакторе фото
элемента (офлайн-очередь) → ложное «AI-запрос добавлен в очередь и
отправится при появлении сети», при этом запрос считается выполненным
и теряется.

**Живое воспроизведение 2026-07-05 ~16:50 UTC** (POST `https://ai.carreports.ru`,
`AiQueue.ChatCompletions`, обе модели `gpt-5.4` и `gpt-5.5`, стабильно
на повторах, ~10.2 с на ответ — похоже на connect-timeout 10 с):

```json
{"response":"success","fromMethod":"AiQueue.ChatCompletions","result":[],
 "errors":[{"message":"Chat failed: Failed to connecting to codex.sale port 443, Connection timed out"}]}
```

При этом `AiQueue.Models` / `AiQueue.Health` отвечают нормально — лежит
только исходящее соединение к LLM-upstream `codex.sale:443` (DNS
резолвится, TCP не устанавливается: файрвол/маршрутизация с сервера или
сам codex.sale недоступен).

**Просьбы:**

1. Восстановить связность `ai.carreports.ru` → `codex.sale:443`
   (проверить с самого сервера: `curl -v --connect-timeout 12 https://codex.sale`).
2. Отдавать такие фейлы как ошибку, а не `response:"success"` с пустым
   `result:[]` — клиент при `success` поле `errors` не читает и
   показывает пользователю сбивающее «пустой ответ» вместо
   «сервис недоступен».

### 🔴 P0: Файлы в заявке

**Use case.** Компания при создании заявки должна прикреплять файлы к заявке
для специалиста: фото, PDF, документы, таблицы и другие обычные файлы.
Видео прикладывать нельзя.

**Сейчас.** Live `Doc` на 2026-05-21 показывает:

- `Storage.CreateRequest` не принимает `files` / `attachments`;
- `Storage.GetRequest` не возвращает файлы заявки;
- отдельного метода вроде `Storage.AttachRequestFile` /
  `ObjectStorage.Request.*` нет;
- общий `ObjectStorage.*` завязан на `reportNumber` и временный `temp`, поэтому
  его нельзя безопасно использовать как постоянные вложения заявки.

**Нужно.** Добавить серверный контракт для постоянных файлов заявки.
Предпочтительный вариант:

1. `ObjectStorage.Request.InitiateMultipartUpload({requestId?, filename, contentLength, contentType})`
2. `ObjectStorage.Request.GetPartUploadUrls({filename, uploadId, partCount})`
3. `ObjectStorage.Request.CompleteMultipartUpload({filename, uploadId, parts})`
4. `Storage.CreateRequest({ ..., attachments: [...] })`
5. `Storage.GetRequest` возвращает `attachments: [{id, filename, contentType, contentLength, viewUrl?}]`
6. `ObjectStorage.Request.GetViewUrl({attachmentId})` для приватного просмотра.

**Frontend rules.**

- Запрещаем `contentType` с префиксом `video/`.
- На клиенте дополнительно фильтруем типы файлов, но финальная валидация должна
  быть на backend.
- Вложения должны быть доступны компании и назначенному специалисту.
- Если заявка ещё не создана, нужен `draftUploadToken` / временная зона хранения,
  которую backend привяжет к заявке после `CreateRequest`.

### 🔴 P0: Аватарка профиля — два блокера в S3-флоу

Клиентский флоу загрузки реализован и протестирован end-to-end
(2026-05-20, sub=2, role=company, platform=web). Шаги 1–4
**работают**, но финал и рендеринг падают на бэкенде.

**Что работает ✅**

| Шаг | Метод | Результат |
|---|---|---|
| 1 | `ObjectStorage.Profile.InitiateProfileMultipartUpload` | ok — `uploadId`, `key=app/user/2/profile/avatar.png`, `publicUrl` |
| 2 | `ObjectStorage.Profile.GetProfilePartUploadUrls` | ok — presigned PUT URL |
| 3 | PUT в S3 (`s3.regru.cloud`) | ok — `ETag "2cd8bde4…8f"` |
| 4 | `ObjectStorage.Profile.CompleteProfileMultipartUpload` | ok — `publicUrl`, `contentSize: 70` |

---

#### Баг 1 — `Storage.UpdateProfile({urlAvatar})` зависает

Запрос **специфичен для поля `urlAvatar`**: висит >25s, `0 bytes received`.
Любое другое поле обрабатывается мгновенно.

```jsonc
// ❌ висит (timeout 25s, 0 байт)
{"method":"Storage.UpdateProfile","params":{"urlAvatar":"https://s3.regru.cloud/reports/app/user/2/profile/avatar.png"}}

// ✅ возвращается за 0.68s
{"method":"Storage.UpdateProfile","params":{"city":"Москва"}}
```

**Гипотеза.** Хэндлер `urlAvatar` синхронно валидирует URL (HEAD/GET
на S3, чтобы проверить что объект существует в папке юзера), напарывается
на 403 (см. Баг 2) и виснет в ретраях/ожидании без таймаута.

**Нужно.** Хэндлер `urlAvatar` не должен блокироваться: ограничить
проверку таймаутом, не делать сетевой fetch на S3 (достаточно проверить
что URL-префикс == `app/user/{userId}/profile/`), вернуть ответ.

---

#### Баг 2 — `publicUrl` не публично читается (403)

«Публичный» URL из Initiate/Complete отдаёт **403 AccessDenied**:

```
GET https://s3.regru.cloud/reports/app/user/2/profile/avatar.png
→ HTTP/1.1 403 Forbidden
  <Error><Code>AccessDenied</Code><BucketName>reports</BucketName></Error>
```

Клиент рендерит аватар через `CachedNetworkImage` — обычный GET **без
авторизации**. С 403 он всегда падает в fallback на инициалы, картинка
не покажется никогда.

**Нужно (на выбор):**

A. Сделать `app/user/*/profile/*` публично-читаемым (bucket policy /
   public-read ACL) — тогда `publicUrl` действительно публичный, как
   обещает имя поля.

B. Если объекты должны оставаться приватными — добавить
   `ObjectStorage.Profile.GetProfileViewUrl({filename})` → presigned GET
   URL, и в `GetProfile.urlAvatar` отдавать presigned-ссылку (с TTL),
   а не «голый» S3-URL.

Вариант A проще для клиента (URL стабильный, кэшируется). Вариант B —
если приватность аватарок принципиальна.

---

### 🟡 P1: Дедуп платных ApiCloud-проверок (конвертер VIN↔госномер)

**Сейчас (ветка `cnc` на 2026-06-22, `wswalker`).** Каждый
`Storage.RunBatchLegalReview` БЕЗУСЛОВНО создаёт новый `LegalReviewCheck`
(Pending) → NATS-джоб → платный HTTP-вызов ApiCloud (~3,4 ₽ за
`api_cloud_converter_search`). Повторный запрос того же VIN/госномера — новое
списание, хотя результат уже лежит в БД:
`src/Service/DoctrineService/Entity/LegalReview/LegalReviewCheck.php` хранит
`vehicle_vin`, `vehicle_gos_number`, `check_type`, `status`,
`response_normalized`, `executed_at`, и под выборку «последний чек по
VIN/номеру + типу» уже созданы индексы `idx_lrc_vin_type_executed` и
`idx_lrc_gos_number_type_executed`. В
`LegalReviewCheckRepository` есть неиспользуемый `findLatestForStepAndType()`.

**Use case.** Специалист определяет авто по VIN/госномеру в шаге «Автомобиль».
Один и тот же номер закономерно вводится повторно: пересоздание черновика,
другое устройство, другой специалист той же компании, повторная инспекция
той же машины. Связка VIN↔госномер меняется редко — повторная оплата
идентичного ответа ApiCloud не даёт ничего.

**Нужно.** В `QueueBatchApiCloudLegalReviewUseCase::queue()` перед созданием
Pending-чека искать последний `Success`-чек с тем же
(`vehicle_vin`|`vehicle_gos_number`) + `check_type`:

1. Если найден и свежее TTL (предложение: 30 дней для конвертера; для
   залога/такси/ГОСТ — короче, они изменчивее) → вернуть его
   `response_normalized` в батче сразу (`status: success`), НЕ дёргая ApiCloud
   и НЕ списывая деньги.
2. Если по тому же входу есть живой `Pending` (моложе N минут) → привязать к
   батчу существующий джоб вместо постановки нового (закрывает и дубли-джобы,
   и накопление «вечных pending»).
3. Опционально: флаг `forceRefresh: true` в `RunBatchLegalReview`, чтобы фронт
   мог явно перезапросить свежие данные, минуя кэш.

**Frontend context.** Клиент уже делает всё, что возможно со своей стороны
(single-flight, переиспользование оплаченного `batchNumber` 24 ч, с 2026-07-05
— локальный персист терминального результата конвертера, 30 дней). Но
клиентский кэш не покрывает другое устройство/другого пользователя и чистку
локального хранилища — глобальный дедуп возможен только на бэке, и все данные
для него уже в `legal_review_check`.

---

### 🟢 P2: Phone-flow для НЕ-штатных специалистов

**Сейчас.** `CreateRequest.assignedSpecialistId` валидирует что
специалист в моей компании. По `GetSpecialists(search:'+7...')`
можно найти НЕ-штатного спеца — но назначить его нельзя.

**Use case.** Компания хочет назначить заявку на специалиста по
номеру телефона, даже если он не в штате (фрилансер, разовый
исполнитель).

**Варианты решения (на выбор бэка):**

A. **Расширить `CreateRequest`** опц. полем `assignedSpecialistPhone`:
   - Если телефон совпал с зарегистрированным спецом → присвоить как assignee
   - Если совпал, но он не в компании → авто-инвайт в company перед assignment (или explicit error)
   - Если телефон не найден → SMS-приглашение «вас назначили на заявку №X, зарегистрируйтесь»

B. **Relax validation** в `assignedSpecialistId` — разрешить назначать
   на любого specialist, не только в моей компании. Тогда фронт сам
   получает userId через `GetSpecialists(search:phone)` и шлёт его.

C. **Invitation-первый flow:** добавить `Storage.InviteSpecialist({phone})`
   → создаёт user-record (если нет) + invitation → специалист принимает
   → попадает в компанию → потом обычное `CreateRequest`. Самый чистый,
   но требует SMS-инфры.

---

### 🟡 P1: Уведомления — чистка ленты и снижение объёма

**Сейчас (live `Doc` 2026-06-10).** Доступны только `Notification.GetNotifications`,
`Notification.MarkRead` (по ОДНОМУ, лишь `reminder`/`system`),
`Notification.ActionNotification`, `Notification.SendNotification`. Удаления,
архива и массовой отметки прочитанным НЕТ. Уведомления только меняют статус и
копятся; пользователь жалуется на «слишком много мусора».

**Use case.** Специалист/компания хотят быстро очистить ленту: отметить всё
прочитанным одним действием и убирать неактуальное.

**Нужно.**

1. `Notification.MarkAllRead({type?, before?})` — массовая отметка `read` для
   всех пассивных (`reminder`/`system`) pending за один вызов. Сейчас фронт
   вынужден циклически дёргать `MarkRead` по каждому id (N запросов) — это
   временный обход в `NotificationController.markAllRead()`.
2. Удаление/архив: `Notification.Delete({notificationId})` или
   `Notification.Archive(...)` (либо авто-истечение прочитанных `system` через
   N дней), чтобы лента не росла бесконечно.
3. **Снизить объём legal-уведомлений.** Бэкенд шлёт ОТДЕЛЬНОЕ system-оповещение
   на КАЖДУЮ ApiCloud-проверку (`legal_review_persisted`: zalog/taxi/gost/…) —
   это основной источник «мусора». Предложение: агрегировать проверки одного
   отчёта в ОДНО итоговое уведомление (или слать только при ошибке/важном
   результате). Конвертер (`api_cloud_converter_search`) фронт уже скрывает.

**Контекст (не баг бэкенда, для сведения).** Детали уведомления на клиенте
больше не показывают сырой payload (`event`, `*Id`, `requestType` и т.п.) —
выводится только курируемый человекочитаемый набор полей.

---

### 🟡 P1: Серверный кэш ApiCloud-ответов по VIN («tempo»)

**Use case.** Один и тот же VIN может проверяться повторно: пере-запуск
проверок в том же отчёте после таймаута, новый отчёт по той же машине,
скан СТС + ручной запуск. Каждый `Storage.RunBatchLegalReview` сейчас идёт
в ApiCloud заново и списывает деньги за те же данные.

**Сейчас.** Проверено по коду wswalker (2026-07-05): кэша ApiCloud-ответов
нет — ни Redis, ни NATS KV, ни таблицы; каждый запуск батча = новое
обращение к ApiCloud. Клиент дедупит только в рамках сессии/черновика
(in-memory кэш конвертера + reuse `batchNumber` из драфта, TTL 24ч) —
межотчётные и межустройственные повторы он закрыть не может.

**Нужно.** Кэш терминальных ответов ApiCloud на стороне бэка:

1. Ключ: `(checkType, vin)` (для fgis — `(checkType, gosNumber)`).
2. TTL ~24 часа (данные ГОСТ/залог/такси за сутки не протухают).
3. `RunBatchLegalReview` при cache-hit по всем типам не обращается к
   ApiCloud и не списывает средства — сразу отдаёт batch с готовыми
   результатами (или прежний `batchNumber`).
4. Кэшировать только терминальные статусы (`found` / `not_found`);
   `error`/timeout не кэшировать.

### 🟡 P1: AiQueue vision — уточнения для скана СТС/ПТС

Фронт добавил распознавание фото СТС/ПТС: фото грузится через
`ObjectStorage.GetTemporaryUploadUrl(reportNumber: "temp")` в `temp/`
(lifecycle 1 день — подтверждено), presigned GET уходит в
`AiQueue.ChatCompletions(fileUrls: [...])`. Работает на документированном
контракте (`fileUrls` → multimodal `image_url`). Вопросы:

1. Максимальный размер изображения / количество `fileUrls` в одном вызове?
2. Какие форматы принимает vision-пайплайн (JPEG точно; HEIC/WebP)?
   Фронт всегда шлёт JPEG ≤2560px по ширине.
3. Есть ли rate limit на `ChatCompletions` с изображениями?

### 🟡 P1: Notification.ActionNotification — ответ дольше клиентского таймаута

**Живой инцидент (2026-07-08).** Сотрудник принимает приглашение в штат →
клиентский таймаут (12с, поднят фронтом до 30с), при этом транзакция на
бэке УСПЕЛА закоммититься (статус + `users.company_id`) → повторный accept
получает `result.error = «Оповещение уже обработано.»`. Фронт добавил
reconcile-восстановление, но первопричина серверная:

1. HTTP-воркер ждёт внутренний IPC-ответ без таймаута
   (`MethodAbstract::publishChannel` — подписка на `…Resp` бессрочная);
   занятый/зависший DoctrineProcess держит соединение до клиентского
   таймаута. Просьба: серверный таймаут на IPC round-trip.
2. NATS-push и email-задачи публикуются ПОСЛЕ commit, но ДО ответа клиенту —
   при медленном NATS ответ задерживается, хотя данные уже записаны.
   Просьба: отвечать клиенту сразу после commit, рассылку — асинхронно.
3. У ошибки «Оповещение уже обработано.» нет машинного кода — фронт вынужден
   матчить русскую подстроку. Просьба: добавить стабильный код (например,
   `notification_already_processed`) рядом с текстом.

---

## Технические детали для всех новых методов

- JSON-RPC 2.0, POST на `https://app.carreports.ru`
- Bearer-токен типа AUTH в `Authorization` header
- Role-gating через JWT claims
- System-notifications через `Notification.Push` + `Notification.GetNotifications`
- Email-уведомления опционально (как в `AcceptRequest` / `RejectRequest`)

## Контакт

Для уточнений по UI-флоу или схемам ответа — см. handoff документы в
`~/.claude/projects/.../memory/handoff_cranky_robinson.md` и
`handoff_intelligent_jackson.md` (Profile API).
