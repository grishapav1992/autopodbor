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

## Технические детали для всех новых методов

- JSON-RPC 2.0, POST на `https://carreports.ru:8085`
- Bearer-токен типа AUTH в `Authorization` header
- Role-gating через JWT claims
- System-notifications через `Notification.Push` + `Notification.GetNotifications`
- Email-уведомления опционально (как в `AcceptRequest` / `RejectRequest`)

## Контакт

Для уточнений по UI-флоу или схемам ответа — см. handoff документы в
`~/.claude/projects/.../memory/handoff_cranky_robinson.md` и
`handoff_intelligent_jackson.md` (Profile API).
