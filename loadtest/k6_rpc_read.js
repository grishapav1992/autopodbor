// Нагрузочный тест read-only JSON-RPC методов бэкенда app.carreports.ru.
//
// ТОЛЬКО read-методы: никаких платных ApiCloud-проверок, Auth (реальные
// звонки) и write-методов. Запускать ТОЛЬКО в согласованное с бэкенд-девом
// окно — известно, что один синхронный ApiCloud-вызов способен положить
// весь воркер-пул (инцидент 2026-06-10).
//
// Запуск:
//   k6 run -e TOKEN=<access-JWT> -e SCENARIO=smoke    loadtest/k6_rpc_read.js
//   k6 run -e TOKEN=<access-JWT> -e SCENARIO=baseline loadtest/k6_rpc_read.js
//   k6 run -e TOKEN=<access-JWT> -e SCENARIO=ramp     loadtest/k6_rpc_read.js
//   k6 run -e TOKEN=<access-JWT> -e SCENARIO=soak     loadtest/k6_rpc_read.js
//
// Доп. флаги:
//   -e RECONNECT=1  — новый TCP+TLS на каждый запрос (так себя ведёт
//                     мобильное приложение: top-level http.post без пула).
//                     Без флага k6 держит keep-alive (поведение web-клиента).
//   -e BASE_URL=... — другой хост (staging), по умолчанию прод.

import http from 'k6/http';
import { check } from 'k6';
import encoding from 'k6/encoding';
import { Rate, Counter } from 'k6/metrics';

const BASE = __ENV.BASE_URL || 'https://app.carreports.ru';
const TOKEN = __ENV.TOKEN || '';
const SCENARIO = __ENV.SCENARIO || 'smoke';

// Доля ответов, где HTTP 200, но RPC вернул не "ok" (ошибки уровня приложения
// nginx-ом не считаются — без этой метрики их не увидеть).
const rpcAppError = new Rate('rpc_app_error');
// Диагностика отказов: считаем провалы по HTTP-статусу / коду ошибки, чтобы
// отличить fast-reject (429/503/reset) от timeout (queue spiral).
const failByStatus = new Counter('fail_by_status');
let failSamples = 0;

const SCENARIOS = {
  // 1 виртуальный пользователь, полминуты — проверить, что сценарий проходит.
  smoke: { executor: 'constant-vus', vus: 1, duration: '30s' },
  // Точка отсчёта: ровно 10 RPS в течение 5 минут.
  baseline: {
    executor: 'constant-arrival-rate',
    rate: 10, timeUnit: '1s', duration: '5m',
    preAllocatedVUs: 30, maxVUs: 100,
  },
  // Поиск потолка: ступени 10→150 RPS. Тест сам ОСТАНОВИТСЯ (abortOnFail),
  // когда ошибок станет >5% — дальше долбить смысла нет.
  ramp: {
    executor: 'ramping-arrival-rate',
    startRate: 5, timeUnit: '1s',
    preAllocatedVUs: 50, maxVUs: 300,
    stages: [
      { target: 10, duration: '2m' },
      { target: 25, duration: '2m' },
      { target: 50, duration: '2m' },
      { target: 100, duration: '2m' },
      { target: 150, duration: '2m' },
    ],
  },
  // Умеренная нагрузка надолго: утечки памяти и деградация со временем.
  soak: {
    executor: 'constant-arrival-rate',
    rate: 15, timeUnit: '1s', duration: '45m',
    preAllocatedVUs: 50, maxVUs: 150,
  },
  // Проба фиксированного RPS со здорового старта: изолировать «упал из-за
  // остаточной перегрузки» от «этот RPS не тянется». -e RATE=NN -e DURATION=Nm.
  probe: {
    executor: 'constant-arrival-rate',
    rate: Number(__ENV.RATE || 15), timeUnit: '1s',
    duration: __ENV.DURATION || '5m',
    preAllocatedVUs: 60, maxVUs: 200,
  },
};

export const options = {
  scenarios: { [SCENARIO]: SCENARIOS[SCENARIO] },
  noConnectionReuse: __ENV.RECONNECT === '1',
  thresholds: {
    // Стоп-кран: >5% транспортных ошибок (после 30с прогрева) → тест гасится.
    http_req_failed: [{ threshold: 'rate<0.05', abortOnFail: true, delayAbortEval: '30s' }],
    rpc_app_error: ['rate<0.05'],
    // Тёплый бэк отвечает за ~0.4-0.5с; p95 выше 3с = деградация.
    http_req_duration: ['p(95)<3000'],
  },
};

// Микс реального использования: списки отчётов — самое частое и самое
// тяжёлое, что дергает приложение; бейдж уведомлений — на каждый заход.
const CALLS = [
  { weight: 30, method: 'Storage.GetSpecialistReport', params: { page: 1, limit: 20, isDraft: false } },
  { weight: 20, method: 'Storage.GetSpecialistReport', params: { page: 1, limit: 20, isDraft: true } },
  { weight: 20, method: 'Notification.GetNotifications', params: { status: 'pending', limit: 1 } },
  { weight: 15, method: 'Notification.GetNotifications', params: { page: 1, limit: 20 } },
  { weight: 15, method: 'Storage.GetProfile', params: {} },
];
const TOTAL_WEIGHT = CALLS.reduce((s, c) => s + c.weight, 0);

function pickCall() {
  let roll = Math.random() * TOTAL_WEIGHT;
  for (const c of CALLS) {
    roll -= c.weight;
    if (roll <= 0) return c;
  }
  return CALLS[0];
}

export function setup() {
  if (!TOKEN) throw new Error('Передай токен: k6 run -e TOKEN=<access JWT> ...');
  const payload = JSON.parse(encoding.b64decode(TOKEN.split('.')[1], 'rawurl', 's'));
  const ttlMin = Math.floor((payload.exp * 1000 - Date.now()) / 60000);
  if (ttlMin <= 0) throw new Error('Access-токен истёк — обнови через RefreshToken');
  console.log(`Токен: sub=${payload.sub} role=${payload.role}, истекает через ${ttlMin} мин`);
  if (ttlMin < 60) console.warn('ВНИМАНИЕ: токена меньше часа — для soak обнови заранее');

  // Прогрев: спящие списковые методы отвечают 40+с на первый хит — это
  // известное свойство бэка, не результат нагрузки. Будим до замеров.
  console.log('Прогрев (первый хит спящего бэка может занять до 60с)...');
  for (const c of CALLS) {
    rpc(c.method, c.params, { timeout: '90s', warmup: true });
  }
  console.log('Прогрев завершён, старт замеров.');
}

function rpc(method, params, opts = {}) {
  const res = http.post(
    BASE,
    JSON.stringify({ jsonrpc: '2.0', id: 0, method, params }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': `Bearer ${TOKEN}`,
      },
      timeout: opts.timeout || '30s',
      tags: { rpc: method, warmup: String(!!opts.warmup) },
    },
  );
  if (!opts.warmup) {
    const ok = check(res, {
      'HTTP 200': (r) => r.status === 200,
      'RPC ok': (r) => {
        try { return r.json('response') === 'ok'; } catch (_) { return false; }
      },
    });
    rpcAppError.add(res.status === 200 && !ok);
    // Категоризуем провал: status=0 → транспортная ошибка (reset/refused),
    // иначе HTTP-код (429/502/503/…). Первые 5 — с телом, для диагноза.
    const failed = res.status !== 200;
    if (failed) {
      const label = res.status === 0 ? `err:${res.error_code}` : `http:${res.status}`;
      failByStatus.add(1, { kind: label });
      if (failSamples < 5) {
        failSamples++;
        console.log(`FAIL ${label} err="${res.error}" body="${String(res.body).slice(0, 120)}"`);
      }
    }
  }
  return res;
}

export default function () {
  const c = pickCall();
  rpc(c.method, c.params);
}
