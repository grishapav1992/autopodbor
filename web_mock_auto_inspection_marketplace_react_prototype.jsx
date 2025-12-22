import React, { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Search,
  Filter,
  ShieldCheck,
  FileText,
  Car,
  User,
  Building2,
  ClipboardList,
  Camera,
  CreditCard,
  BadgeCheck,
  AlertTriangle,
  ChevronRight,
  ChevronLeft,
  Plus,
  X,
  MessageSquare,
  BarChart3,
  Settings,
  Lock,
  CheckCircle2,
} from "lucide-react";

// shadcn/ui
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Separator } from "@/components/ui/separator";
import { Switch } from "@/components/ui/switch";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Progress } from "@/components/ui/progress";

/**
 * WEB MOCK (кликабельный прототип)
 * - Роли: Покупатель, Автоподборщик, Админ
 * - Потоки: каталог отчетов -> покупка -> просмотр; каталог исполнителей -> заказ услуги;
 *          кабинет подборщика -> создание отчета -> публикация; админ -> модерация/верификация
 *
 * Примечание: это UI-мок, данные заглушки.
 */

// ---------- Mock Data ----------
const mockReports = [
  {
    id: "R-10241",
    city: "Москва",
    make: "Toyota",
    model: "Camry",
    year: 2019,
    mileage: 78000,
    price: 1290,
    inspectedAt: "2025-12-22",
    validUntil: "2025-12-29",
    verdict: "Рекомендуется",
    riskLevel: "низкий",
    defects: {
      legal: 0,
      body: 2,
      tech: 1,
      electrics: 1,
      interior: 1,
    },
    author: { name: "Илья П.", org: "AutoCheck Pro", verified: true, rating: 4.8, sales: 312 },
    preview: {
      summary:
        "Юридически чисто. 2 локальных окраса без силовых элементов. Есть ошибка по датчику парковки.",
      photos: 4,
      videos: 1,
      obd: true,
    },
  },
  {
    id: "R-10577",
    city: "Санкт‑Петербург",
    make: "BMW",
    model: "3 Series",
    year: 2017,
    mileage: 112000,
    price: 890,
    inspectedAt: "2025-12-20",
    validUntil: "2025-12-25",
    verdict: "Сомнительно",
    riskLevel: "средний",
    defects: {
      legal: 1,
      body: 3,
      tech: 2,
      electrics: 0,
      interior: 2,
    },
    author: { name: "Мария С.", org: null, verified: true, rating: 4.6, sales: 148 },
    preview: {
      summary:
        "Есть регистрационные особенности. Следы ремонта в задней части, без геометрии. Нужна диагностика цепи ГРМ.",
      photos: 6,
      videos: 2,
      obd: true,
    },
  },
  {
    id: "R-11003",
    city: "Казань",
    make: "Kia",
    model: "Rio",
    year: 2020,
    mileage: 54000,
    price: 490,
    inspectedAt: "2025-12-18",
    validUntil: "2025-12-21",
    verdict: "Не рекомендую",
    riskLevel: "высокий",
    defects: {
      legal: 2,
      body: 4,
      tech: 3,
      electrics: 2,
      interior: 2,
    },
    author: { name: "Алексей К.", org: "ГородАвтоЭксперт", verified: false, rating: 4.1, sales: 57 },
    preview: {
      summary:
        "Ограничения/риски в юридической проверке. Силовой ремонт передка. Множественные ошибки по блокам.",
      photos: 8,
      videos: 1,
      obd: true,
    },
  },
];

const mockPros = [
  {
    id: "P-2001",
    name: "Илья П.",
    org: "AutoCheck Pro",
    city: "Москва",
    verified: true,
    rating: 4.8,
    jobs: 940,
    specialties: ["VAG", "Toyota/Lexus", "премиум"],
    equipment: ["Толщиномер", "OBD", "Эндоскоп"],
    fromPrice: 4500,
    reports: 312,
  },
  {
    id: "P-2002",
    name: "Мария С.",
    org: null,
    city: "Санкт‑Петербург",
    verified: true,
    rating: 4.6,
    jobs: 510,
    specialties: ["BMW", "Mercedes", "кузов"],
    equipment: ["Толщиномер", "OBD"],
    fromPrice: 3900,
    reports: 148,
  },
  {
    id: "P-2003",
    name: "Алексей К.",
    org: "ГородАвтоЭксперт",
    city: "Казань",
    verified: false,
    rating: 4.1,
    jobs: 210,
    specialties: ["бюджет", "такси‑риски"],
    equipment: ["Толщиномер"],
    fromPrice: 3200,
    reports: 57,
  },
];

const mockAdmin = {
  moderationQueue: [
    { id: "R-12001", type: "report", reason: "Жалоба: скрыт VIN/нечитаемые фото", createdAt: "2025-12-22 10:15", actor: "Покупатель" },
    { id: "R-11944", type: "report", reason: "Жалоба: несоответствие выводов и доказательств", createdAt: "2025-12-21 19:40", actor: "Покупатель" },
  ],
  verificationQueue: [
    { id: "V-8801", type: "pro", name: "Сергей Н.", city: "Москва", createdAt: "2025-12-22 09:10" },
    { id: "V-8802", type: "org", name: "ПроверкаАвто24", city: "СПб", createdAt: "2025-12-21 14:05" },
  ],
};

// ---------- Helpers ----------
function cn(...classes) {
  return classes.filter(Boolean).join(" ");
}

function daysLeft(validUntil) {
  const today = new Date("2025-12-22T12:00:00"); // fixed for mock
  const d = new Date(validUntil + "T23:59:59");
  const diff = Math.ceil((d.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
  return diff;
}

function moneyRub(n) {
  return new Intl.NumberFormat("ru-RU").format(n) + " ₽";
}

function riskBadge(riskLevel) {
  const map = {
    низкий: "bg-black/5 text-black border-black/10",
    средний: "bg-black/10 text-black border-black/15",
    высокий: "bg-black/15 text-black border-black/20",
  };
  return map[riskLevel] || "bg-black/5";
}

// ---------- UI Shell ----------
function AppShell({ role, setRole, page, setPage, children }) {
  const roleLabel = {
    buyer: "Покупатель",
    pro: "Автоподборщик",
    admin: "Админ",
  }[role];

  const nav = useMemo(() => {
    if (role === "buyer")
      return [
        { key: "buyer.reports", label: "Отчеты", icon: FileText },
        { key: "buyer.pros", label: "Подборщики", icon: User },
        { key: "buyer.orders", label: "Мои заказы", icon: ClipboardList },
        { key: "buyer.library", label: "Покупки", icon: Lock },
        { key: "buyer.profile", label: "Профиль", icon: Settings },
      ];
    if (role === "pro")
      return [
        { key: "pro.dashboard", label: "Обзор", icon: BarChart3 },
        { key: "pro.reports", label: "Мои отчеты", icon: FileText },
        { key: "pro.builder", label: "Создать отчет", icon: Plus },
        { key: "pro.orders", label: "Заказы", icon: ClipboardList },
        { key: "pro.profile", label: "Профиль", icon: Settings },
      ];
    return [
      { key: "admin.moderation", label: "Модерация", icon: ShieldCheck },
      { key: "admin.verification", label: "Верификация", icon: BadgeCheck },
      { key: "admin.fin", label: "Платежи", icon: CreditCard },
      { key: "admin.users", label: "Пользователи", icon: User },
      { key: "admin.settings", label: "Настройки", icon: Settings },
    ];
  }, [role]);

  return (
    <div className="min-h-screen bg-gradient-to-b from-white to-black/[0.03]">
      <TopBar role={role} roleLabel={roleLabel} setRole={setRole} />
      <div className="mx-auto max-w-6xl px-4 pb-10">
        <div className="mt-4 grid grid-cols-12 gap-4">
          <aside className="col-span-12 md:col-span-3">
            <Card className="rounded-2xl shadow-sm">
              <CardHeader className="pb-3">
                <CardTitle className="text-base">Навигация</CardTitle>
                <CardDescription>Роль: {roleLabel}</CardDescription>
              </CardHeader>
              <CardContent className="pt-0">
                <div className="flex flex-col gap-1">
                  {nav.map((n) => {
                    const Icon = n.icon;
                    const active = page === n.key;
                    return (
                      <button
                        key={n.key}
                        onClick={() => setPage(n.key)}
                        className={cn(
                          "flex items-center gap-2 rounded-xl px-3 py-2 text-sm transition",
                          active
                            ? "bg-black text-white"
                            : "hover:bg-black/5 text-black"
                        )}
                      >
                        <Icon className="h-4 w-4" />
                        <span>{n.label}</span>
                        <ChevronRight className={cn("ml-auto h-4 w-4", active ? "opacity-80" : "opacity-30")} />
                      </button>
                    );
                  })}
                </div>
                <Separator className="my-4" />
                <div className="text-xs text-black/60 leading-relaxed">
                  Это кликабельный web‑мок. Данные — заглушки.
                </div>
              </CardContent>
            </Card>
          </aside>

          <main className="col-span-12 md:col-span-9">
            <AnimatePresence mode="wait">
              <motion.div
                key={page}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.18 }}
              >
                {children}
              </motion.div>
            </AnimatePresence>
          </main>
        </div>
      </div>
    </div>
  );
}

function TopBar({ role, roleLabel, setRole }) {
  return (
    <div className="sticky top-0 z-20 border-b bg-white/80 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
        <div className="flex items-center gap-3">
          <div className="h-9 w-9 rounded-2xl bg-black text-white grid place-items-center shadow-sm">
            <Car className="h-4 w-4" />
          </div>
          <div>
            <div className="text-sm font-semibold">AutoInspect</div>
            <div className="text-xs text-black/60">Маркетплейс отчетов и услуг автоподбора</div>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <Badge variant="outline" className="rounded-xl">{roleLabel}</Badge>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" className="rounded-xl">Сменить роль</Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-56">
              <DropdownMenuLabel>Роли</DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={() => setRole("buyer")}>Покупатель</DropdownMenuItem>
              <DropdownMenuItem onClick={() => setRole("pro")}>Автоподборщик</DropdownMenuItem>
              <DropdownMenuItem onClick={() => setRole("admin")}>Админ</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </div>
  );
}

// ---------- Buyer Screens ----------
function BuyerReports({ onOpenReport, ownedIds, onPurchase }) {
  const [q, setQ] = useState("");
  const [city, setCity] = useState("all");
  const [verdict, setVerdict] = useState("all");
  const [onlyValid, setOnlyValid] = useState(true);

  const list = useMemo(() => {
    return mockReports
      .filter((r) => {
        const text = `${r.make} ${r.model} ${r.city} ${r.id}`.toLowerCase();
        if (q.trim() && !text.includes(q.toLowerCase())) return false;
        if (city !== "all" && r.city !== city) return false;
        if (verdict !== "all" && r.verdict !== verdict) return false;
        if (onlyValid && daysLeft(r.validUntil) < 0) return false;
        return true;
      })
      .sort((a, b) => (a.inspectedAt < b.inspectedAt ? 1 : -1));
  }, [q, city, verdict, onlyValid]);

  return (
    <div className="space-y-4">
      <Card className="rounded-2xl shadow-sm">
        <CardHeader>
          <CardTitle className="text-base">Каталог отчетов</CardTitle>
          <CardDescription>
            Поиск по марке/модели/городу. Покупка открывает полный доступ.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-12 gap-3">
            <div className="col-span-12 md:col-span-6">
              <Label className="text-xs">Поиск</Label>
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 opacity-40" />
                <Input
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  className="pl-9 rounded-xl"
                  placeholder="Например: Camry, Москва, R-10241"
                />
              </div>
            </div>

            <div className="col-span-6 md:col-span-2">
              <Label className="text-xs">Город</Label>
              <Select value={city} onValueChange={setCity}>
                <SelectTrigger className="rounded-xl">
                  <SelectValue placeholder="Все" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Все</SelectItem>
                  <SelectItem value="Москва">Москва</SelectItem>
                  <SelectItem value="Санкт‑Петербург">Санкт‑Петербург</SelectItem>
                  <SelectItem value="Казань">Казань</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="col-span-6 md:col-span-2">
              <Label className="text-xs">Вердикт</Label>
              <Select value={verdict} onValueChange={setVerdict}>
                <SelectTrigger className="rounded-xl">
                  <SelectValue placeholder="Все" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Все</SelectItem>
                  <SelectItem value="Рекомендуется">Рекомендуется</SelectItem>
                  <SelectItem value="Сомнительно">Сомнительно</SelectItem>
                  <SelectItem value="Не рекомендую">Не рекомендую</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="col-span-12 md:col-span-2 flex items-end">
              <div className="w-full rounded-xl border px-3 py-2 flex items-center justify-between">
                <div className="text-sm flex items-center gap-2">
                  <Filter className="h-4 w-4 opacity-50" />
                  Только актуальные
                </div>
                <Switch checked={onlyValid} onCheckedChange={setOnlyValid} />
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {list.map((r) => {
          const owned = ownedIds.includes(r.id);
          const left = daysLeft(r.validUntil);
          const expired = left < 0;
          return (
            <Card key={r.id} className="rounded-2xl shadow-sm">
              <CardHeader className="pb-2">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <CardTitle className="text-base flex items-center gap-2">
                      {r.make} {r.model} {r.year}
                      {r.author.verified ? (
                        <Badge variant="outline" className="rounded-xl flex items-center gap-1">
                          <BadgeCheck className="h-3.5 w-3.5" /> Проверено
                        </Badge>
                      ) : (
                        <Badge variant="outline" className="rounded-xl flex items-center gap-1">
                          <AlertTriangle className="h-3.5 w-3.5" /> Не верифицирован
                        </Badge>
                      )}
                    </CardTitle>
                    <CardDescription>
                      {r.city} • {r.mileage.toLocaleString("ru-RU")} км • Осмотр: {r.inspectedAt}
                    </CardDescription>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-semibold">{moneyRub(r.price)}</div>
                    <div className="text-xs text-black/60">Отчет {r.id}</div>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex flex-wrap items-center gap-2">
                  <Badge className={cn("rounded-xl border", riskBadge(r.riskLevel))} variant="outline">
                    Риск: {r.riskLevel}
                  </Badge>
                  <Badge variant="outline" className="rounded-xl">
                    Вердикт: {r.verdict}
                  </Badge>
                  <Badge variant="outline" className="rounded-xl">
                    Фото: {r.preview.photos}
                  </Badge>
                  <Badge variant="outline" className="rounded-xl">
                    Видео: {r.preview.videos}
                  </Badge>
                  <Badge variant="outline" className="rounded-xl">
                    OBD: {r.preview.obd ? "есть" : "нет"}
                  </Badge>
                </div>

                <div className="text-sm text-black/80 leading-relaxed">
                  {r.preview.summary}
                </div>

                <div className="rounded-xl border p-3">
                  <div className="flex items-center justify-between text-sm">
                    <div className="text-black/70">Актуальность</div>
                    <div className={cn("font-medium", expired ? "text-black" : "text-black")}>
                      {expired ? "Просрочен" : `${left} дн.`}
                    </div>
                  </div>
                  <div className="mt-2">
                    <Progress value={Math.max(0, Math.min(100, (left / 7) * 100))} />
                    <div className="mt-1 text-xs text-black/60">До: {r.validUntil}</div>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    className="rounded-xl w-full"
                    onClick={() => onOpenReport(r.id)}
                  >
                    Открыть превью
                    <ChevronRight className="ml-2 h-4 w-4" />
                  </Button>
                  {owned ? (
                    <Button className="rounded-xl w-full" onClick={() => onOpenReport(r.id)}>
                      Мой доступ
                    </Button>
                  ) : (
                    <Button className="rounded-xl w-full" onClick={() => onPurchase(r.id)}>
                      Купить
                    </Button>
                  )}
                </div>

                <div className="text-xs text-black/60">
                  Автор: {r.author.name}
                  {r.author.org ? ` • ${r.author.org}` : ""} • рейтинг {r.author.rating} • продаж {r.author.sales}
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </div>
  );
}

function BuyerReportDetails({ reportId, ownedIds, onBack, onPurchase }) {
  const r = useMemo(() => mockReports.find((x) => x.id === reportId), [reportId]);
  const owned = ownedIds.includes(reportId);

  if (!r) return null;

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Button variant="outline" className="rounded-xl" onClick={onBack}>
          <ChevronLeft className="h-4 w-4 mr-1" /> Назад
        </Button>
        <Badge variant="outline" className="rounded-xl">Отчет {r.id}</Badge>
      </div>

      <Card className="rounded-2xl shadow-sm">
        <CardHeader>
          <div className="flex items-start justify-between gap-4">
            <div>
              <CardTitle className="text-lg">
                {r.make} {r.model} {r.year}
              </CardTitle>
              <CardDescription>
                {r.city} • {r.mileage.toLocaleString("ru-RU")} км • Осмотр: {r.inspectedAt} • До: {r.validUntil}
              </CardDescription>
            </div>
            <div className="text-right">
              <div className="text-lg font-semibold">{moneyRub(r.price)}</div>
              <div className="text-xs text-black/60">Вердикт: {r.verdict}</div>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-12 gap-3">
            <InfoPill icon={ShieldCheck} label="Юридика" value={`${r.defects.legal} риск(ов)`} />
            <InfoPill icon={Car} label="Кузов" value={`${r.defects.body} дефект(ов)`} />
            <InfoPill icon={ClipboardList} label="Техника" value={`${r.defects.tech} дефект(ов)`} />
            <InfoPill icon={Settings} label="Электрика" value={`${r.defects.electrics} дефект(ов)`} />
            <InfoPill icon={User} label="Салон" value={`${r.defects.interior} дефект(ов)`} />
            <div className="col-span-12 md:col-span-3">
              <div className="h-full rounded-2xl border p-3">
                <div className="text-xs text-black/60">Доступ</div>
                <div className="mt-1 text-sm font-medium">
                  {owned ? "Куплено" : "Только превью"}
                </div>
                <div className="mt-2 text-xs text-black/60">Автор: {r.author.name}</div>
              </div>
            </div>
          </div>

          {!owned && (
            <div className="rounded-2xl border p-4 bg-black/[0.02]">
              <div className="flex items-start gap-3">
                <Lock className="h-5 w-5 mt-0.5" />
                <div className="flex-1">
                  <div className="text-sm font-semibold">Полный отчет скрыт до покупки</div>
                  <div className="text-sm text-black/70 mt-1">
                    Доступ откроет фото/видео по пунктам, результаты диагностики, детальные риски и итоговую смету.
                  </div>
                </div>
                <Button className="rounded-xl" onClick={() => onPurchase(r.id)}>
                  Купить за {moneyRub(r.price)}
                </Button>
              </div>
            </div>
          )}

          <Tabs defaultValue="summary">
            <TabsList className="rounded-2xl">
              <TabsTrigger value="summary">Превью</TabsTrigger>
              <TabsTrigger value="full" disabled={!owned}>Полный отчет</TabsTrigger>
              <TabsTrigger value="author">Исполнитель</TabsTrigger>
            </TabsList>

            <TabsContent value="summary" className="mt-4">
              <Card className="rounded-2xl shadow-sm">
                <CardHeader>
                  <CardTitle className="text-base">Краткое резюме</CardTitle>
                  <CardDescription>То, что видно до покупки</CardDescription>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div className="text-sm leading-relaxed">{r.preview.summary}</div>
                  <div className="grid grid-cols-3 gap-2">
                    <MediaTile title="Фото" value={r.preview.photos} icon={Camera} />
                    <MediaTile title="Видео" value={r.preview.videos} icon={Camera} />
                    <MediaTile title="OBD" value={r.preview.obd ? "Да" : "Нет"} icon={Settings} />
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="full" className="mt-4">
              <Card className="rounded-2xl shadow-sm">
                <CardHeader>
                  <CardTitle className="text-base">Полный отчет</CardTitle>
                  <CardDescription>Данные‑заглушки для демонстрации</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <Section title="1) Юридическая проверка" items={[
                    "Залоги/ограничения: не обнаружены",
                    "История регистрации: 2 владельца",
                    "Такси/лизинг: не выявлено",
                  ]} />
                  <Section title="2) Документы" items={[
                    "СТС/ПТС: визуально без признаков подделки",
                    "VIN/номер кузова: соответствует",
                  ]} />
                  <Section title="3) Кузов" items={[
                    "Толщиномер: локальные окрасы (2 элемента)",
                    "Силовая часть: без вмешательств",
                    "Зазоры: в норме",
                  ]} />
                  <Section title="4) Техническое состояние" items={[
                    "Двигатель: запотевание по крышке клапанов",
                    "Трансмиссия: без рывков на тест‑драйве",
                    "Подвеска: есть стук стойки стабилизатора",
                  ]} />
                  <Section title="5) Электрика" items={[
                    "OBD: 1 ошибка по парковочному датчику",
                    "Функции: стеклоподъемники/климат в норме",
                  ]} />
                  <Section title="Итог" items={[
                    `Вердикт: ${r.verdict}`,
                    "Ориентир затрат: 20–35 тыс. ₽",
                    "Рекомендация: торг по кузову и подвеске",
                  ]} />
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="author" className="mt-4">
              <Card className="rounded-2xl shadow-sm">
                <CardHeader>
                  <CardTitle className="text-base">Исполнитель</CardTitle>
                  <CardDescription>Профиль и доверие</CardDescription>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <div className="text-sm font-semibold">{r.author.name}</div>
                      <div className="text-sm text-black/70">{r.author.org || "Самозанятый/частный"}</div>
                      <div className="text-xs text-black/60 mt-1">Рейтинг: {r.author.rating} • Продаж отчетов: {r.author.sales}</div>
                    </div>
                    <div className="flex items-center gap-2">
                      {r.author.verified ? (
                        <Badge className="rounded-xl" variant="outline">
                          <BadgeCheck className="h-4 w-4 mr-1" /> Верифицирован
                        </Badge>
                      ) : (
                        <Badge className="rounded-xl" variant="outline">
                          <AlertTriangle className="h-4 w-4 mr-1" /> Не верифицирован
                        </Badge>
                      )}
                      <Button variant="outline" className="rounded-xl">
                        Заказать услугу
                      </Button>
                    </div>
                  </div>
                  <Separator />
                  <div className="text-sm text-black/70 leading-relaxed">
                    Здесь будет описание исполнителя, список оборудования, регионы выезда и тарифы.
                  </div>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  );
}

function BuyerPros({ onOpenPro, onCreateOrder }) {
  const [q, setQ] = useState("");
  const [city, setCity] = useState("all");
  const [verifiedOnly, setVerifiedOnly] = useState(false);

  const list = useMemo(() => {
    return mockPros
      .filter((p) => {
        const text = `${p.name} ${p.org || ""} ${p.city} ${p.specialties.join(" ")}`.toLowerCase();
        if (q.trim() && !text.includes(q.toLowerCase())) return false;
        if (city !== "all" && p.city !== city) return false;
        if (verifiedOnly && !p.verified) return false;
        return true;
      })
      .sort((a, b) => b.rating - a.rating);
  }, [q, city, verifiedOnly]);

  return (
    <div className="space-y-4">
      <Card className="rounded-2xl shadow-sm">
        <CardHeader>
          <CardTitle className="text-base">Подборщики и организации</CardTitle>
          <CardDescription>Выберите исполнителя и оформите заказ услуги</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-12 gap-3">
            <div className="col-span-12 md:col-span-6">
              <Label className="text-xs">Поиск</Label>
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 opacity-40" />
                <Input
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  className="pl-9 rounded-xl"
                  placeholder="Имя, организация, специализация"
                />
              </div>
            </div>

            <div className="col-span-6 md:col-span-3">
              <Label className="text-xs">Город</Label>
              <Select value={city} onValueChange={setCity}>
                <SelectTrigger className="rounded-xl">
                  <SelectValue placeholder="Все" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Все</SelectItem>
                  <SelectItem value="Москва">Москва</SelectItem>
                  <SelectItem value="Санкт‑Петербург">Санкт‑Петербург</SelectItem>
                  <SelectItem value="Казань">Казань</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="col-span-6 md:col-span-3 flex items-end">
              <div className="w-full rounded-xl border px-3 py-2 flex items-center justify-between">
                <div className="text-sm flex items-center gap-2">
                  <BadgeCheck className="h-4 w-4 opacity-60" /> Только верифицированные
                </div>
                <Switch checked={verifiedOnly} onCheckedChange={setVerifiedOnly} />
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {list.map((p) => (
          <Card key={p.id} className="rounded-2xl shadow-sm">
            <CardHeader className="pb-2">
              <div className="flex items-start justify-between">
                <div>
                  <CardTitle className="text-base flex items-center gap-2">
                    {p.name}
                    {p.verified ? (
                      <Badge variant="outline" className="rounded-xl flex items-center gap-1">
                        <BadgeCheck className="h-3.5 w-3.5" /> Верифицирован
                      </Badge>
                    ) : (
                      <Badge variant="outline" className="rounded-xl flex items-center gap-1">
                        <AlertTriangle className="h-3.5 w-3.5" /> Не верифицирован
                      </Badge>
                    )}
                  </CardTitle>
                  <CardDescription>
                    {p.org ? (
                      <span className="inline-flex items-center gap-1">
                        <Building2 className="h-3.5 w-3.5" /> {p.org}
                      </span>
                    ) : (
                      "Частный исполнитель"
                    )}
                    {" "}• {p.city}
                  </CardDescription>
                </div>
                <div className="text-right">
                  <div className="text-sm font-semibold">от {moneyRub(p.fromPrice)}</div>
                  <div className="text-xs text-black/60">рейтинг {p.rating}</div>
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex flex-wrap gap-2">
                {p.specialties.map((s) => (
                  <Badge key={s} variant="outline" className="rounded-xl">{s}</Badge>
                ))}
              </div>
              <div className="text-xs text-black/60">
                Оборудование: {p.equipment.join(", ")} • Выполнено осмотров: {p.jobs} • Отчетов в каталоге: {p.reports}
              </div>
              <div className="flex items-center gap-2">
                <Button variant="outline" className="rounded-xl w-full" onClick={() => onOpenPro(p.id)}>
                  Профиль
                  <ChevronRight className="ml-2 h-4 w-4" />
                </Button>
                <Button className="rounded-xl w-full" onClick={() => onCreateOrder(p.id)}>
                  Заказать
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}

function BuyerProDetails({ proId, onBack, onCreateOrder }) {
  const p = useMemo(() => mockPros.find((x) => x.id === proId), [proId]);
  if (!p) return null;

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Button variant="outline" className="rounded-xl" onClick={onBack}>
          <ChevronLeft className="h-4 w-4 mr-1" /> Назад
        </Button>
        <Badge variant="outline" className="rounded-xl">Профиль {p.id}</Badge>
      </div>

      <Card className="rounded-2xl shadow-sm">
        <CardHeader>
          <div className="flex items-start justify-between gap-4">
            <div>
              <CardTitle className="text-lg flex items-center gap-2">
                {p.name}
                {p.verified ? (
                  <Badge variant="outline" className="rounded-xl flex items-center gap-1">
                    <BadgeCheck className="h-4 w-4" /> Верифицирован
                  </Badge>
                ) : (
                  <Badge variant="outline" className="rounded-xl flex items-center gap-1">
                    <AlertTriangle className="h-4 w-4" /> Не верифицирован
                  </Badge>
                )}
              </CardTitle>
              <CardDescription>
                {p.org ? `${p.org} • ` : ""}{p.city} • рейтинг {p.rating} • осмотров {p.jobs}
              </CardDescription>
            </div>
            <div className="text-right">
              <div className="text-sm font-semibold">от {moneyRub(p.fromPrice)}</div>
              <div className="text-xs text-black/60">отчетов в каталоге: {p.reports}</div>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-12 gap-3">
            <div className="col-span-12 md:col-span-6 rounded-2xl border p-4">
              <div className="text-sm font-semibold">Специализация</div>
              <div className="mt-2 flex flex-wrap gap-2">
                {p.specialties.map((s) => (
                  <Badge key={s} variant="outline" className="rounded-xl">{s}</Badge>
                ))}
              </div>
            </div>
            <div className="col-span-12 md:col-span-6 rounded-2xl border p-4">
              <div className="text-sm font-semibold">Оборудование</div>
              <div className="mt-2 flex flex-wrap gap-2">
                {p.equipment.map((e) => (
                  <Badge key={e} variant="outline" className="rounded-xl">{e}</Badge>
                ))}
              </div>
            </div>
          </div>

          <div className="rounded-2xl border p-4 bg-black/[0.02]">
            <div className="flex items-start justify-between gap-3">
              <div>
                <div className="text-sm font-semibold">Описание</div>
                <div className="text-sm text-black/70 mt-1 leading-relaxed">
                  Здесь будет описание услуг, зон выезда, SLA и примеры отчетов. В мок‑версии текст статический.
                </div>
              </div>
              <Button className="rounded-xl" onClick={() => onCreateOrder(p.id)}>
                Заказать услугу
              </Button>
            </div>
          </div>

          <div className="rounded-2xl border p-4">
            <div className="text-sm font-semibold">Примеры отчетов</div>
            <div className="mt-2 grid grid-cols-1 md:grid-cols-2 gap-2">
              {mockReports
                .filter((r) => r.author.name === p.name)
                .map((r) => (
                  <div key={r.id} className="rounded-xl border p-3">
                    <div className="text-sm font-medium">{r.make} {r.model} {r.year}</div>
                    <div className="text-xs text-black/60">{r.city} • {r.inspectedAt} • {moneyRub(r.price)}</div>
                    <div className="mt-2 text-xs text-black/70">Вердикт: {r.verdict}</div>
                  </div>
                ))}
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

function BuyerOrders() {
  return (
    <Card className="rounded-2xl shadow-sm">
      <CardHeader>
        <CardTitle className="text-base">Мои заказы</CardTitle>
        <CardDescription>Здесь будут заказы услуг автоподбора</CardDescription>
      </CardHeader>
      <CardContent>
        <EmptyState
          icon={ClipboardList}
          title="Пока нет заказов"
          description="Создайте заказ у выбранного автоподборщика — здесь появится статус и чат."
        />
      </CardContent>
    </Card>
  );
}

function BuyerLibrary({ ownedIds, onOpenReport }) {
  const owned = mockReports.filter((r) => ownedIds.includes(r.id));
  return (
    <Card className="rounded-2xl shadow-sm">
      <CardHeader>
        <CardTitle className="text-base">Покупки</CardTitle>
        <CardDescription>Ваши купленные отчеты</CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        {owned.length === 0 ? (
          <EmptyState
            icon={Lock}
            title="Нет купленных отчетов"
            description="Купите любой отчет — он появится здесь."
          />
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {owned.map((r) => (
              <div key={r.id} className="rounded-2xl border p-4">
                <div className="text-sm font-semibold">{r.make} {r.model} {r.year}</div>
                <div className="text-xs text-black/60">{r.city} • {r.inspectedAt} • {r.id}</div>
                <div className="mt-2 flex items-center justify-between">
                  <Badge variant="outline" className="rounded-xl">{r.verdict}</Badge>
                  <Button size="sm" className="rounded-xl" onClick={() => onOpenReport(r.id)}>
                    Открыть
                  </Button>
                </div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function BuyerProfile() {
  return (
    <Card className="rounded-2xl shadow-sm">
      <CardHeader>
        <CardTitle className="text-base">Профиль</CardTitle>
        <CardDescription>Настройки аккаунта пользователя</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-12 gap-3">
          <div className="col-span-12 md:col-span-6">
            <Label className="text-xs">Имя</Label>
            <Input className="rounded-xl" defaultValue="Гость" />
          </div>
          <div className="col-span-12 md:col-span-6">
            <Label className="text-xs">Телефон / Email</Label>
            <Input className="rounded-xl" defaultValue="+7•••" />
          </div>
        </div>
        <Separator />
        <div className="flex items-center justify-between rounded-2xl border p-4">
          <div>
            <div className="text-sm font-semibold">Уведомления</div>
            <div className="text-sm text-black/70">О готовности отчетов и изменениях заказов</div>
          </div>
          <Switch defaultChecked />
        </div>
        <Button variant="outline" className="rounded-xl">Выйти</Button>
      </CardContent>
    </Card>
  );
}

// ---------- Pro Screens ----------
function ProDashboard({ stats }) {
  return (
    <div className="space-y-4">
      <Card className="rounded-2xl shadow-sm">
        <CardHeader>
          <CardTitle className="text-base">Обзор</CardTitle>
          <CardDescription>Ключевые метрики исполнителя (заглушки)</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <Metric title="Продажи отчетов" value={stats.salesCount} icon={FileText} />
            <Metric title="Доход" value={moneyRub(stats.revenue)} icon={CreditCard} />
            <Metric title="Новые заказы" value={stats.newOrders} icon={ClipboardList} />
          </div>
        </CardContent>
      </Card>

      <Card className="rounded-2xl shadow-sm">
        <CardHeader>
          <CardTitle className="text-base">Быстрые действия</CardTitle>
          <CardDescription>Частые сценарии</CardDescription>
        </CardHeader>
        <CardContent className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <QuickAction icon={Plus} title="Создать отчет" desc="Мастер по шагам" />
          <QuickAction icon={ClipboardList} title="Заказы" desc="Управление статусами" />
          <QuickAction icon={Settings} title="Профиль" desc="Тарифы и регионы" />
        </CardContent>
      </Card>
    </div>
  );
}

function ProReports({ myReports, onEdit, onOpen, onCreate }) {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-lg font-semibold">Мои отчеты</div>
          <div className="text-sm text-black/60">Черновики и опубликованные</div>
        </div>
        <Button className="rounded-xl" onClick={onCreate}>
          <Plus className="h-4 w-4 mr-2" /> Создать
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {myReports.map((r) => (
          <Card key={r.id} className="rounded-2xl shadow-sm">
            <CardHeader className="pb-2">
              <CardTitle className="text-base">{r.make} {r.model} {r.year}</CardTitle>
              <CardDescription>
                {r.city} • {r.mileage.toLocaleString("ru-RU")} км • {r.id}
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex flex-wrap gap-2">
                <Badge variant="outline" className="rounded-xl">Статус: {r.status}</Badge>
                <Badge variant="outline" className="rounded-xl">Цена: {moneyRub(r.price)}</Badge>
                <Badge variant="outline" className="rounded-xl">До: {r.validUntil}</Badge>
              </div>
              <div className="flex items-center gap-2">
                <Button variant="outline" className="rounded-xl w-full" onClick={() => onOpen(r.id)}>
                  Просмотр
                </Button>
                <Button className="rounded-xl w-full" onClick={() => onEdit(r.id)}>
                  Редактировать
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}

function ProOrders() {
  return (
    <Card className="rounded-2xl shadow-sm">
      <CardHeader>
        <CardTitle className="text-base">Заказы</CardTitle>
        <CardDescription>Очередь заказов услуг (заглушка)</CardDescription>
      </CardHeader>
      <CardContent>
        <EmptyState
          icon={ClipboardList}
          title="Пока нет активных заказов"
          description="Когда клиент оформит заказ, он появится здесь со статусами и чатом."
        />
      </CardContent>
    </Card>
  );
}

function ProProfile() {
  return (
    <Card className="rounded-2xl shadow-sm">
      <CardHeader>
        <CardTitle className="text-base">Профиль автоподборщика</CardTitle>
        <CardDescription>Управление данными, тарифами и зонами выезда</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-12 gap-3">
          <div className="col-span-12 md:col-span-6">
            <Label className="text-xs">Имя</Label>
            <Input className="rounded-xl" defaultValue="Илья П." />
          </div>
          <div className="col-span-12 md:col-span-6">
            <Label className="text-xs">Организация</Label>
            <Input className="rounded-xl" defaultValue="AutoCheck Pro" />
          </div>
          <div className="col-span-12 md:col-span-6">
            <Label className="text-xs">Город</Label>
            <Input className="rounded-xl" defaultValue="Москва" />
          </div>
          <div className="col-span-12 md:col-span-6">
            <Label className="text-xs">Цена разового осмотра (от)</Label>
            <Input className="rounded-xl" defaultValue="4500" />
          </div>
        </div>
        <Separator />
        <div className="rounded-2xl border p-4">
          <div className="flex items-start justify-between">
            <div>
              <div className="text-sm font-semibold">Верификация</div>
              <div className="text-sm text-black/70">Подтвердите документы, чтобы увеличить доверие</div>
            </div>
            <Button variant="outline" className="rounded-xl">Отправить на проверку</Button>
          </div>
        </div>
        <Button className="rounded-xl">Сохранить</Button>
      </CardContent>
    </Card>
  );
}

function ProReportBuilder({ draft, setDraft, onPublish, onExit }) {
  const steps = [
    { key: "car", title: "Авто", icon: Car },
    { key: "legal", title: "Юридика", icon: ShieldCheck },
    { key: "body", title: "Кузов", icon: Car },
    { key: "tech", title: "Техника", icon: ClipboardList },
    { key: "electrics", title: "Электрика", icon: Settings },
    { key: "interior", title: "Салон", icon: User },
    { key: "summary", title: "Итог", icon: CheckCircle2 },
  ];
  const [step, setStep] = useState(steps[0].key);

  const idx = steps.findIndex((s) => s.key === step);
  const progress = ((idx + 1) / steps.length) * 100;

  const next = () => setStep(steps[Math.min(idx + 1, steps.length - 1)].key);
  const prev = () => setStep(steps[Math.max(idx - 1, 0)].key);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-lg font-semibold">Создание отчета</div>
          <div className="text-sm text-black/60">Мастер по шагам (черновик)</div>
        </div>
        <Button variant="outline" className="rounded-xl" onClick={onExit}>
          <X className="h-4 w-4 mr-2" /> Закрыть
        </Button>
      </div>

      <Card className="rounded-2xl shadow-sm">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <CardTitle className="text-base">Шаг {idx + 1} из {steps.length}</CardTitle>
            <Badge variant="outline" className="rounded-xl">Черновик</Badge>
          </div>
          <CardDescription>Заполните ключевые поля. Медиа и доказательства — заглушки.</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap gap-2">
            {steps.map((s) => {
              const Icon = s.icon;
              const active = s.key === step;
              return (
                <button
                  key={s.key}
                  onClick={() => setStep(s.key)}
                  className={cn(
                    "flex items-center gap-2 rounded-xl border px-3 py-2 text-sm",
                    active ? "bg-black text-white border-black" : "hover:bg-black/5"
                  )}
                >
                  <Icon className="h-4 w-4" /> {s.title}
                </button>
              );
            })}
          </div>

          <div className="mt-4">
            <Progress value={progress} />
          </div>

          <div className="mt-5">
            {step === "car" && (
              <div className="grid grid-cols-12 gap-3">
                <Field col="col-span-12 md:col-span-4" label="Марка" value={draft.make} onChange={(v) => setDraft({ ...draft, make: v })} />
                <Field col="col-span-12 md:col-span-4" label="Модель" value={draft.model} onChange={(v) => setDraft({ ...draft, model: v })} />
                <Field col="col-span-12 md:col-span-4" label="Год" value={draft.year} onChange={(v) => setDraft({ ...draft, year: v })} />
                <Field col="col-span-12 md:col-span-6" label="VIN" value={draft.vin} onChange={(v) => setDraft({ ...draft, vin: v })} placeholder="WVWZZZ..." />
                <Field col="col-span-12 md:col-span-6" label="Госномер" value={draft.plate} onChange={(v) => setDraft({ ...draft, plate: v })} placeholder="А123АА77" />
                <Field col="col-span-12 md:col-span-6" label="Пробег" value={draft.mileage} onChange={(v) => setDraft({ ...draft, mileage: v })} placeholder="78000" />
                <Field col="col-span-12 md:col-span-6" label="Город" value={draft.city} onChange={(v) => setDraft({ ...draft, city: v })} placeholder="Москва" />
              </div>
            )}

            {step === "legal" && (
              <div className="space-y-3">
                <CheckRow title="Залоги" value={draft.legal.pledge} onChange={(v) => setDraft({ ...draft, legal: { ...draft.legal, pledge: v } })} />
                <CheckRow title="Ограничения" value={draft.legal.restrict} onChange={(v) => setDraft({ ...draft, legal: { ...draft.legal, restrict: v } })} />
                <CheckRow title="Угон" value={draft.legal.stolen} onChange={(v) => setDraft({ ...draft, legal: { ...draft.legal, stolen: v } })} />
                <CheckRow title="Такси" value={draft.legal.taxi} onChange={(v) => setDraft({ ...draft, legal: { ...draft.legal, taxi: v } })} />
                <Textarea
                  className="rounded-xl"
                  value={draft.legal.note}
                  onChange={(e) => setDraft({ ...draft, legal: { ...draft.legal, note: e.target.value } })}
                  placeholder="Комментарий по юридике"
                />
              </div>
            )}

            {step === "body" && (
              <div className="space-y-3">
                <Textarea
                  className="rounded-xl"
                  value={draft.body.paint}
                  onChange={(e) => setDraft({ ...draft, body: { ...draft.body, paint: e.target.value } })}
                  placeholder="Замеры ЛКП: элементы, значения, выводы"
                />
                <Textarea
                  className="rounded-xl"
                  value={draft.body.power}
                  onChange={(e) => setDraft({ ...draft, body: { ...draft.body, power: e.target.value } })}
                  placeholder="Силовая часть: лонжероны/стойки/крыша"
                />
                <MediaStub />
              </div>
            )}

            {step === "tech" && (
              <div className="space-y-3">
                <Textarea
                  className="rounded-xl"
                  value={draft.tech.engine}
                  onChange={(e) => setDraft({ ...draft, tech: { ...draft.tech, engine: e.target.value } })}
                  placeholder="Двигатель: течи, шумы, жидкости"
                />
                <Textarea
                  className="rounded-xl"
                  value={draft.tech.gearbox}
                  onChange={(e) => setDraft({ ...draft, tech: { ...draft.tech, gearbox: e.target.value } })}
                  placeholder="Трансмиссия: поведение, пинки, ошибки"
                />
                <Textarea
                  className="rounded-xl"
                  value={draft.tech.susp}
                  onChange={(e) => setDraft({ ...draft, tech: { ...draft.tech, susp: e.target.value } })}
                  placeholder="Подвеска/ходовая: люфты, стуки"
                />
                <MediaStub />
              </div>
            )}

            {step === "electrics" && (
              <div className="space-y-3">
                <Textarea
                  className="rounded-xl"
                  value={draft.electrics.obd}
                  onChange={(e) => setDraft({ ...draft, electrics: { ...draft.electrics, obd: e.target.value } })}
                  placeholder="OBD/диагностика: блоки, ошибки"
                />
                <Textarea
                  className="rounded-xl"
                  value={draft.electrics.note}
                  onChange={(e) => setDraft({ ...draft, electrics: { ...draft.electrics, note: e.target.value } })}
                  placeholder="Электроника: проверка функций"
                />
                <MediaStub />
              </div>
            )}

            {step === "interior" && (
              <div className="space-y-3">
                <Textarea
                  className="rounded-xl"
                  value={draft.interior.wear}
                  onChange={(e) => setDraft({ ...draft, interior: { ...draft.interior, wear: e.target.value } })}
                  placeholder="Салон: износ в сравнении с пробегом"
                />
                <Textarea
                  className="rounded-xl"
                  value={draft.interior.trim}
                  onChange={(e) => setDraft({ ...draft, interior: { ...draft.interior, trim: e.target.value } })}
                  placeholder="Комплектация: соответствие заявленной"
                />
                <MediaStub />
              </div>
            )}

            {step === "summary" && (
              <div className="space-y-3">
                <div className="grid grid-cols-12 gap-3">
                  <div className="col-span-12 md:col-span-6">
                    <Label className="text-xs">Вердикт</Label>
                    <Select value={draft.verdict} onValueChange={(v) => setDraft({ ...draft, verdict: v })}>
                      <SelectTrigger className="rounded-xl">
                        <SelectValue placeholder="Выберите" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="Рекомендуется">Рекомендуется</SelectItem>
                        <SelectItem value="Сомнительно">Сомнительно</SelectItem>
                        <SelectItem value="Не рекомендую">Не рекомендую</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="col-span-12 md:col-span-3">
                    <Label className="text-xs">Цена отчета</Label>
                    <Input
                      className="rounded-xl"
                      value={draft.price}
                      onChange={(e) => setDraft({ ...draft, price: e.target.value })}
                      placeholder="1290"
                    />
                  </div>
                  <div className="col-span-12 md:col-span-3">
                    <Label className="text-xs">Актуально до</Label>
                    <Input
                      className="rounded-xl"
                      value={draft.validUntil}
                      onChange={(e) => setDraft({ ...draft, validUntil: e.target.value })}
                      placeholder="2025-12-29"
                    />
                  </div>
                </div>
                <Textarea
                  className="rounded-xl"
                  value={draft.summary}
                  onChange={(e) => setDraft({ ...draft, summary: e.target.value })}
                  placeholder="Итоговое резюме и рекомендации"
                />
                <div className="rounded-2xl border p-4 bg-black/[0.02]">
                  <div className="text-sm font-semibold">Публикация</div>
                  <div className="text-sm text-black/70 mt-1">
                    После публикации отчет станет доступен в каталоге. В мок‑версии публикация добавит его в «Мои отчеты».
                  </div>
                </div>
              </div>
            )}
          </div>

          <div className="mt-6 flex items-center justify-between">
            <Button variant="outline" className="rounded-xl" onClick={prev} disabled={idx === 0}>
              <ChevronLeft className="h-4 w-4 mr-1" /> Назад
            </Button>
            {idx < steps.length - 1 ? (
              <Button className="rounded-xl" onClick={next}>
                Далее <ChevronRight className="h-4 w-4 ml-1" />
              </Button>
            ) : (
              <Button className="rounded-xl" onClick={onPublish}>
                Опубликовать
              </Button>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

// ---------- Admin Screens ----------
function AdminModeration() {
  return (
    <div className="space-y-4">
      <Card className="rounded-2xl shadow-sm">
        <CardHeader>
          <CardTitle className="text-base">Модерация</CardTitle>
          <CardDescription>Очередь жалоб и проблемных отчетов</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          {mockAdmin.moderationQueue.map((i) => (
            <div key={i.id} className="rounded-2xl border p-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold">{i.id}</div>
                  <div className="text-sm text-black/70 mt-1">{i.reason}</div>
                  <div className="text-xs text-black/60 mt-2">Создано: {i.createdAt} • Инициатор: {i.actor}</div>
                </div>
                <div className="flex items-center gap-2">
                  <Button variant="outline" className="rounded-xl">Открыть</Button>
                  <Button className="rounded-xl">Скрыть</Button>
                </div>
              </div>
            </div>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}

function AdminVerification() {
  return (
    <Card className="rounded-2xl shadow-sm">
      <CardHeader>
        <CardTitle className="text-base">Верификация</CardTitle>
        <CardDescription>Заявки от исполнителей и организаций</CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        {mockAdmin.verificationQueue.map((v) => (
          <div key={v.id} className="rounded-2xl border p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <div className="text-sm font-semibold">{v.name}</div>
                <div className="text-sm text-black/70">Тип: {v.type === "pro" ? "исполнитель" : "организация"} • {v.city}</div>
                <div className="text-xs text-black/60 mt-2">Заявка: {v.id} • {v.createdAt}</div>
              </div>
              <div className="flex items-center gap-2">
                <Button variant="outline" className="rounded-xl">Открыть</Button>
                <Button className="rounded-xl">Подтвердить</Button>
              </div>
            </div>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}

function AdminFin() {
  return (
    <Card className="rounded-2xl shadow-sm">
      <CardHeader>
        <CardTitle className="text-base">Платежи</CardTitle>
        <CardDescription>Транзакции и возвраты (заглушка)</CardDescription>
      </CardHeader>
      <CardContent>
        <EmptyState
          icon={CreditCard}
          title="Нет данных"
          description="В MVP здесь будут транзакции, комиссии, возвраты и payout исполнителям."
        />
      </CardContent>
    </Card>
  );
}

function AdminUsers() {
  return (
    <Card className="rounded-2xl shadow-sm">
      <CardHeader>
        <CardTitle className="text-base">Пользователи</CardTitle>
        <CardDescription>Список аккаунтов и блокировки (заглушка)</CardDescription>
      </CardHeader>
      <CardContent>
        <EmptyState
          icon={User}
          title="Список пользователей"
          description="В MVP: поиск, роли, блокировки, аудит действий."
        />
      </CardContent>
    </Card>
  );
}

function AdminSettings() {
  return (
    <Card className="rounded-2xl shadow-sm">
      <CardHeader>
        <CardTitle className="text-base">Настройки платформы</CardTitle>
        <CardDescription>Комиссии, шаблоны отчетов, справочники (заглушка)</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-12 gap-3">
          <div className="col-span-12 md:col-span-4">
            <Label className="text-xs">Комиссия с отчета (%)</Label>
            <Input className="rounded-xl" defaultValue="15" />
          </div>
          <div className="col-span-12 md:col-span-4">
            <Label className="text-xs">Комиссия с услуги (%)</Label>
            <Input className="rounded-xl" defaultValue="12" />
          </div>
          <div className="col-span-12 md:col-span-4">
            <Label className="text-xs">Актуальность по умолчанию (дней)</Label>
            <Input className="rounded-xl" defaultValue="7" />
          </div>
        </div>
        <Button className="rounded-xl">Сохранить</Button>
      </CardContent>
    </Card>
  );
}

// ---------- Shared UI ----------
function InfoPill({ icon: Icon, label, value }) {
  return (
    <div className="col-span-12 md:col-span-3">
      <div className="rounded-2xl border p-3 h-full">
        <div className="text-xs text-black/60 flex items-center gap-2">
          <Icon className="h-4 w-4 opacity-60" /> {label}
        </div>
        <div className="mt-1 text-sm font-medium">{value}</div>
      </div>
    </div>
  );
}

function MediaTile({ title, value, icon: Icon }) {
  return (
    <div className="rounded-2xl border p-3">
      <div className="text-xs text-black/60 flex items-center gap-2">
        <Icon className="h-4 w-4 opacity-60" /> {title}
      </div>
      <div className="mt-1 text-sm font-semibold">{value}</div>
    </div>
  );
}

function Section({ title, items }) {
  return (
    <div className="rounded-2xl border p-4">
      <div className="text-sm font-semibold">{title}</div>
      <ul className="mt-2 space-y-1 text-sm text-black/70 list-disc pl-5">
        {items.map((x, i) => (
          <li key={i}>{x}</li>
        ))}
      </ul>
    </div>
  );
}

function EmptyState({ icon: Icon, title, description }) {
  return (
    <div className="rounded-2xl border bg-white p-8 text-center">
      <div className="mx-auto h-12 w-12 rounded-2xl bg-black text-white grid place-items-center">
        <Icon className="h-5 w-5" />
      </div>
      <div className="mt-4 text-sm font-semibold">{title}</div>
      <div className="mt-1 text-sm text-black/70 max-w-md mx-auto">{description}</div>
    </div>
  );
}

function Metric({ title, value, icon: Icon }) {
  return (
    <div className="rounded-2xl border p-4">
      <div className="text-xs text-black/60 flex items-center gap-2">
        <Icon className="h-4 w-4 opacity-60" /> {title}
      </div>
      <div className="mt-2 text-2xl font-semibold">{value}</div>
    </div>
  );
}

function QuickAction({ icon: Icon, title, desc }) {
  return (
    <div className="rounded-2xl border p-4 hover:bg-black/[0.02] transition">
      <div className="flex items-start gap-3">
        <div className="h-10 w-10 rounded-2xl bg-black text-white grid place-items-center">
          <Icon className="h-5 w-5" />
        </div>
        <div>
          <div className="text-sm font-semibold">{title}</div>
          <div className="text-sm text-black/70">{desc}</div>
        </div>
      </div>
    </div>
  );
}

function Field({ col, label, value, onChange, placeholder }) {
  return (
    <div className={col}>
      <Label className="text-xs">{label}</Label>
      <Input
        className="rounded-xl"
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  );
}

function CheckRow({ title, value, onChange }) {
  return (
    <div className="rounded-2xl border p-4 flex items-center justify-between">
      <div className="text-sm font-semibold">{title}</div>
      <Select value={value} onValueChange={onChange}>
        <SelectTrigger className="rounded-xl w-56">
          <SelectValue placeholder="Выберите" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="ok">ОК</SelectItem>
          <SelectItem value="risk">Риск</SelectItem>
          <SelectItem value="na">Нет данных</SelectItem>
        </SelectContent>
      </Select>
    </div>
  );
}

function MediaStub() {
  return (
    <div className="rounded-2xl border p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-sm font-semibold">Медиа</div>
          <div className="text-sm text-black/70 mt-1">В MVP: загрузка фото/видео с привязкой к пунктам.</div>
        </div>
        <Button variant="outline" className="rounded-xl">
          <Camera className="h-4 w-4 mr-2" /> Добавить
        </Button>
      </div>
    </div>
  );
}

// ---------- Purchase + Order Dialogs ----------
function PurchaseDialog({ open, onOpenChange, report, onConfirm }) {
  if (!report) return null;
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="rounded-2xl">
        <DialogHeader>
          <DialogTitle>Покупка отчета</DialogTitle>
          <DialogDescription>
            {report.make} {report.model} {report.year} • {report.city} • {report.id}
          </DialogDescription>
        </DialogHeader>
        <div className="rounded-2xl border p-4 bg-black/[0.02]">
          <div className="flex items-start justify-between gap-3">
            <div>
              <div className="text-sm font-semibold">Итого к оплате</div>
              <div className="text-2xl font-semibold mt-1">{moneyRub(report.price)}</div>
              <div className="text-sm text-black/70 mt-2">
                После оплаты вы получите доступ к полному отчету и медиа‑доказательствам.
              </div>
            </div>
            <div className="h-10 w-10 rounded-2xl bg-black text-white grid place-items-center">
              <CreditCard className="h-5 w-5" />
            </div>
          </div>
        </div>
        <DialogFooter className="gap-2 sm:gap-0">
          <Button variant="outline" className="rounded-xl" onClick={() => onOpenChange(false)}>
            Отмена
          </Button>
          <Button className="rounded-xl" onClick={onConfirm}>
            Оплатить
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function OrderDialog({ open, onOpenChange, pro, onConfirm }) {
  const [type, setType] = useState("inspection");
  const [note, setNote] = useState("");

  React.useEffect(() => {
    if (open) {
      setType("inspection");
      setNote("");
    }
  }, [open]);

  if (!pro) return null;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="rounded-2xl">
        <DialogHeader>
          <DialogTitle>Заказ услуги</DialogTitle>
          <DialogDescription>
            Исполнитель: {pro.name}{pro.org ? ` • ${pro.org}` : ""} • {pro.city}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3">
          <div>
            <Label className="text-xs">Тип услуги</Label>
            <Select value={type} onValueChange={setType}>
              <SelectTrigger className="rounded-xl">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="inspection">Разовый осмотр</SelectItem>
                <SelectItem value="turnkey">Подбор под ключ</SelectItem>
                <SelectItem value="legal">Юр.проверка</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <Label className="text-xs">Комментарий</Label>
            <Textarea
              className="rounded-xl"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="Например: интересует конкретная машина, нужен выезд сегодня/завтра, бюджет..."
            />
          </div>
          <div className="rounded-2xl border p-4 bg-black/[0.02]">
            <div className="text-sm font-semibold">Ориентир цены</div>
            <div className="text-sm text-black/70 mt-1">от {moneyRub(pro.fromPrice)} (зависит от задачи и региона)</div>
          </div>
        </div>

        <DialogFooter className="gap-2 sm:gap-0">
          <Button variant="outline" className="rounded-xl" onClick={() => onOpenChange(false)}>
            Отмена
          </Button>
          <Button className="rounded-xl" onClick={onConfirm}>
            Отправить заказ
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ---------- Main App ----------
export default function WebMockAutoInspect() {
  const [role, setRole] = useState("buyer");
  const [page, setPage] = useState("buyer.reports");

  const [ownedIds, setOwnedIds] = useState([]);
  const [selectedReportId, setSelectedReportId] = useState(null);
  const [selectedProId, setSelectedProId] = useState(null);

  const [purchaseOpen, setPurchaseOpen] = useState(false);
  const [orderOpen, setOrderOpen] = useState(false);
  const [pendingReportId, setPendingReportId] = useState(null);
  const [pendingProId, setPendingProId] = useState(null);

  // Pro side state
  const [proReports, setProReports] = useState(() =>
    mockReports
      .filter((r) => r.author.name === "Илья П.")
      .map((r) => ({ ...r, status: "Опубликован" }))
      .concat([
        {
          id: "D-9001",
          city: "Москва",
          make: "Skoda",
          model: "Octavia",
          year: 2018,
          mileage: 98000,
          price: 990,
          validUntil: "2025-12-28",
          status: "Черновик",
        },
      ])
  );

  const blankDraft = {
    make: "",
    model: "",
    year: "",
    vin: "",
    plate: "",
    mileage: "",
    city: "",
    legal: { pledge: "ok", restrict: "ok", stolen: "ok", taxi: "na", note: "" },
    body: { paint: "", power: "" },
    tech: { engine: "", gearbox: "", susp: "" },
    electrics: { obd: "", note: "" },
    interior: { wear: "", trim: "" },
    verdict: "Рекомендуется",
    price: "1290",
    validUntil: "2025-12-29",
    summary: "",
  };

  const [draft, setDraft] = useState(blankDraft);
  const [builderOpen, setBuilderOpen] = useState(false);

  React.useEffect(() => {
    // keep page coherent when switching roles
    if (role === "buyer" && !page.startsWith("buyer")) setPage("buyer.reports");
    if (role === "pro" && !page.startsWith("pro")) setPage("pro.dashboard");
    if (role === "admin" && !page.startsWith("admin")) setPage("admin.moderation");
  }, [role]);

  const pendingReport = useMemo(
    () => mockReports.find((r) => r.id === pendingReportId),
    [pendingReportId]
  );
  const pendingPro = useMemo(() => mockPros.find((p) => p.id === pendingProId), [pendingProId]);

  const buyerContent = () => {
    if (selectedReportId) {
      return (
        <BuyerReportDetails
          reportId={selectedReportId}
          ownedIds={ownedIds}
          onBack={() => setSelectedReportId(null)}
          onPurchase={(id) => {
            setPendingReportId(id);
            setPurchaseOpen(true);
          }}
        />
      );
    }
    if (selectedProId) {
      return (
        <BuyerProDetails
          proId={selectedProId}
          onBack={() => setSelectedProId(null)}
          onCreateOrder={(id) => {
            setPendingProId(id);
            setOrderOpen(true);
          }}
        />
      );
    }

    switch (page) {
      case "buyer.reports":
        return (
          <BuyerReports
            onOpenReport={(id) => setSelectedReportId(id)}
            ownedIds={ownedIds}
            onPurchase={(id) => {
              setPendingReportId(id);
              setPurchaseOpen(true);
            }}
          />
        );
      case "buyer.pros":
        return (
          <BuyerPros
            onOpenPro={(id) => setSelectedProId(id)}
            onCreateOrder={(id) => {
              setPendingProId(id);
              setOrderOpen(true);
            }}
          />
        );
      case "buyer.orders":
        return <BuyerOrders />;
      case "buyer.library":
        return <BuyerLibrary ownedIds={ownedIds} onOpenReport={(id) => setSelectedReportId(id)} />;
      case "buyer.profile":
        return <BuyerProfile />;
      default:
        return null;
    }
  };

  const proContent = () => {
    if (builderOpen) {
      return (
        <ProReportBuilder
          draft={draft}
          setDraft={setDraft}
          onExit={() => setBuilderOpen(false)}
          onPublish={() => {
            const newId = "R-" + Math.floor(12000 + Math.random() * 800).toString();
            const newReport = {
              id: newId,
              city: draft.city || "Москва",
              make: draft.make || "",
              model: draft.model || "",
              year: Number(draft.year) || 2020,
              mileage: Number(draft.mileage) || 0,
              price: Number(draft.price) || 990,
              validUntil: draft.validUntil || "2025-12-29",
              status: "Опубликован",
            };
            setProReports([newReport, ...proReports]);
            setDraft(blankDraft);
            setBuilderOpen(false);
            setPage("pro.reports");
          }}
        />
      );
    }

    switch (page) {
      case "pro.dashboard":
        return <ProDashboard stats={{ salesCount: 312, revenue: 312 * 1290, newOrders: 3 }} />;
      case "pro.reports":
        return (
          <ProReports
            myReports={proReports}
            onCreate={() => setBuilderOpen(true)}
            onOpen={() => {}}
            onEdit={() => setBuilderOpen(true)}
          />
        );
      case "pro.builder":
        setTimeout(() => setBuilderOpen(true), 0);
        return null;
      case "pro.orders":
        return <ProOrders />;
      case "pro.profile":
        return <ProProfile />;
      default:
        return null;
    }
  };

  const adminContent = () => {
    switch (page) {
      case "admin.moderation":
        return <AdminModeration />;
      case "admin.verification":
        return <AdminVerification />;
      case "admin.fin":
        return <AdminFin />;
      case "admin.users":
        return <AdminUsers />;
      case "admin.settings":
        return <AdminSettings />;
      default:
        return null;
    }
  };

  return (
    <>
      <AppShell role={role} setRole={setRole} page={page} setPage={setPage}>
        {role === "buyer" ? buyerContent() : role === "pro" ? proContent() : adminContent()}
      </AppShell>

      <PurchaseDialog
        open={purchaseOpen}
        onOpenChange={setPurchaseOpen}
        report={pendingReport}
        onConfirm={() => {
          if (pendingReportId && !ownedIds.includes(pendingReportId)) {
            setOwnedIds([...ownedIds, pendingReportId]);
          }
          setPurchaseOpen(false);
          if (pendingReportId) setSelectedReportId(pendingReportId);
          setPendingReportId(null);
        }}
      />

      <OrderDialog
        open={orderOpen}
        onOpenChange={setOrderOpen}
        pro={pendingPro}
        onConfirm={() => {
          setOrderOpen(false);
          setPendingProId(null);
          // In MVP: create order and navigate to orders
          setPage("buyer.orders");
        }}
      />
    </>
  );
}
