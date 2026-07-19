## Git: одна рабочая ветка `dev`

Правило для ЛЮБОЙ ИИ-сессии (Claude, Codex, прочие агенты) — оно же в AGENTS.md:

- **Не работай в `main` напрямую.** Вся работа всех сессий и задач идёт в ОДНОЙ общей ветке `dev`: она есть — продолжай в ней (`git switch dev`); нет — создай от свежего `main`. Новые ветки (`feature/*`, worktree и т.п.) НЕ создавать без явной просьбы пользователя в текущем ходе. (Прецедент 2026-07-19: схема «ветка на задачу» расплодила 8 локальных веток — пользователь потребовал вернуть одну ветку.)
- Все коммиты — в `dev`. Мерж/пуш в `main` — только по явной просьбе пользователя в текущем ходе («залей в main»), а не как стандартное завершение задачи.
- Перед выводами о состоянии кода запускай `git status` и `git log --oneline -5`: параллельно работают несколько ИИ-сессий и сам пользователь, tip и дерево меняются между ходами.
- **Не коммить молча чужие незакоммиченные правки.** Если в дереве есть изменения, которых ты в этой сессии не делал, — покажи их пользователю и спроси, включать ли. (Прецедент 2026-07-15: коммит `dcd941c` молча увёз замену фильтра заявок из параллельной сессии — пользователь потом искал «пропавшую» функцию.)

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
