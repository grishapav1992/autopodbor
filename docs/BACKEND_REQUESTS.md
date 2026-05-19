# Запросы к backend-team

Документ собирает API-расширения, нужные фронту для довода флоу
«Заявки от компании» (новый раздел) и догрейда старых задач.

Состояние на **2026-05-18**, после `f02c4dc`.

---

## Уже сделано ✅

| Метод | Статус | Закрыло |
|---|---|---|
| `Storage.GetSpecialists({page, limit, search?, cities?, minRating?})` | live | Поиск специалиста по телефону/email (search exact-match) |
| `Storage.GetCompanySpecialists({page, limit})` | live | Список штатных специалистов компании |
| `Storage.CreateRequest({assignedSpecialistId, ...})` | live | Назначение заявки на специалиста при создании |
| `Storage.AcceptRequest / RejectRequest / CompleteRequest` | live | Lifecycle заявки |
| `Storage.GetRequest.assignedSpecialist/assignedSpecialistId` | live | Компания видит назначенного специалиста в detail-screen |
| `Storage.GetRequest.reportId/reportNumber` | live | Компания может создать share-ссылку готового отчёта из detail-screen |
| `Storage.AssignSpecialist` | live | Переназначение специалиста на заявку в `created` / `await_payment` |
| `Storage.CancelRequest` | live | Отмена заявки до оплаты/начала работы |

---

## Нужно от backend (приоритет ↓)

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

### 🟢 P2: `isVerifyEmail` в `GetProfile` response

**Use case.** Email-верификация: после смены email юзер получает код
на новый адрес, вводит через `Storage.VerifyEmail({code})`. Backend
успешно верифицирует, **но** не возвращает флаг подтверждения в
`GetProfile` — фронт не может показать «Email подтверждён» badge
после рестарта приложения. Pending-state живёт только локально.

**Что нужно:**

```jsonc
// GetProfile.result добавить:
"isVerifyEmail": true | false
```

Аналогично существующему `isVerifyCompany`. Без этого нет positive-
verification UI cue для email после reopen приложения.

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
