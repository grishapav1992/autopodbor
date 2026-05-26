#!/usr/bin/env bash
#
# setup-graphify.sh — разворачивает локальный рантайм graphify на
# Mac / Linux / WSL. Идемпотентен, безопасно перезапускать.
#
#   bash tools/setup-graphify.sh
#
# Что делает (шаги 2-5 из ручной инструкции):
#   - находит Python 3.10+
#   - ставит graphifyy + mcp
#   - ставит skill (graphify install)
#   - строит начальный граф (AST-only, без LLM/API расходов)
#   - ставит git-хуки + чинит allowlist для homebrew-путей (python@3.12)
#   - генерит .mcp.json с абсолютным путём к интерпретатору
#
# Граф (`graphify-out/`) и `.mcp.json` — в .gitignore, поэтому на
# каждой новой машине их надо построить/сгенерить заново. Этот скрипт
# именно для этого.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"
echo "[setup-graphify] project root: $PROJECT_ROOT"

# ── 1. Найти Python 3.10+ ────────────────────────────────────────────────
PYTHON=""
for c in python3.13 python3.12 python3.11 python3.10 python3 python; do
  if command -v "$c" >/dev/null 2>&1; then
    if "$c" -c 'import sys; sys.exit(0 if sys.version_info[:2] >= (3,10) else 1)' 2>/dev/null; then
      PYTHON="$(command -v "$c")"
      break
    fi
  fi
done
if [ -z "$PYTHON" ]; then
  echo "[setup-graphify] ОШИБКА: не найден Python 3.10+." >&2
  echo "  macOS:  brew install python@3.12" >&2
  echo "  Linux:  sudo apt install python3.12  (или аналог дистрибутива)" >&2
  exit 1
fi
echo "[setup-graphify] python: $PYTHON ($("$PYTHON" --version 2>&1))"

# Канонический путь интерпретатора — его кладём в .mcp.json
PYTHON_EXE="$("$PYTHON" -c 'import sys; print(sys.executable)')"

# ── 2. Поставить graphifyy + mcp ─────────────────────────────────────────
# homebrew / externally-managed окружения требуют --break-system-packages
PIP_FLAGS=""
if "$PYTHON" -m pip install --help 2>/dev/null | grep -q -- '--break-system-packages'; then
  PIP_FLAGS="--break-system-packages"
fi
echo "[setup-graphify] установка graphifyy + mcp..."
"$PYTHON" -m pip install $PIP_FLAGS -q graphifyy mcp

# ── 3. Поставить skill (идемпотентно) ────────────────────────────────────
"$PYTHON" -m graphify install || true

# ── 4. Построить начальный граф (AST-only, с нуля) ───────────────────────
echo "[setup-graphify] построение графа (AST, без LLM)..."
if "$PYTHON" "$SCRIPT_DIR/_graphify_bootstrap.py"; then
  echo "[setup-graphify] граф построен."
else
  echo "[setup-graphify] AST-сборка не удалась — запусти '/graphify .' из Claude Code." >&2
fi

# ── 5. Git-хуки + фикс allowlist (@) для homebrew-путей ──────────────────
"$PYTHON" -m graphify hook install || true
HOOKS_DIR="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/hooks"
for hook in post-commit post-checkout; do
  hp="$HOOKS_DIR/$hook"
  if [ -f "$hp" ]; then
    # Разрешаем '@' в allowlist пути к Python — иначе homebrew
    # python@3.12 отбраковывается и хук молча no-op'ит.
    sed -i.bak 's#\[!a-zA-Z0-9/_\.-\]#[!a-zA-Z0-9/_.@-]#g' "$hp" && rm -f "$hp.bak"
  fi
done
echo "[setup-graphify] хуки установлены + пропатчены."

# ── 6. Сгенерить .mcp.json (абсолютные пути, per-machine) ────────────────
cat > "$PROJECT_ROOT/.mcp.json" <<EOF
{
  "mcpServers": {
    "graphify": {
      "command": "$PYTHON_EXE",
      "args": [
        "-m",
        "graphify.serve",
        "$PROJECT_ROOT/graphify-out/graph.json"
      ]
    }
  }
}
EOF
echo "[setup-graphify] .mcp.json создан (command=$PYTHON_EXE)"

echo ""
echo "[setup-graphify] Готово. Дальше:"
echo "  1. Перезапусти Claude Code в проекте — подхватит .mcp.json."
echo "  2. Для богатого семантического графа: '/graphify . --mode deep' из Claude Code."
