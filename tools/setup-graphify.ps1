# setup-graphify.ps1 — разворачивает локальный рантайм graphify на Windows.
# Идемпотентен, безопасно перезапускать.
#
#   powershell -ExecutionPolicy Bypass -File tools\setup-graphify.ps1
#
# Что делает:
#   - находит Python 3.10+ (через py launcher или python)
#   - ставит graphifyy + mcp
#   - ставит skill (graphify install)
#   - строит начальный граф (AST-only, без LLM/API расходов)
#   - ставит git-хуки (git-for-windows гоняет .sh через встроенный bash)
#   - генерит .mcp.json с абсолютным путём к интерпретатору
#
# Граф (graphify-out\) и .mcp.json — в .gitignore, на каждой новой
# машине их надо построить/сгенерить заново. Скрипт для этого.
#
# Если Claude Code крутится под WSL — используй setup-graphify.sh, а не этот.

$ErrorActionPreference = "Stop"

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot
Write-Host "[setup-graphify] project root: $ProjectRoot"

# -- 1. Найти Python 3.10+ ------------------------------------------------
$PyExe  = $null
$PyArgs = @()

function Test-Py310 {
    param([string]$exe, [string[]]$exeArgs)
    try {
        $out = & $exe @exeArgs -c "import sys; print(1 if sys.version_info[:2] >= (3,10) else 0)" 2>$null
        return ($out -eq "1")
    } catch { return $false }
}

if (Get-Command py -ErrorAction SilentlyContinue) {
    foreach ($v in @("-3.13","-3.12","-3.11","-3.10")) {
        if (Test-Py310 "py" @($v)) { $PyExe = "py"; $PyArgs = @($v); break }
    }
    if (-not $PyExe -and (Test-Py310 "py" @())) { $PyExe = "py" }
}
if (-not $PyExe -and (Get-Command python -ErrorAction SilentlyContinue)) {
    if (Test-Py310 "python" @()) { $PyExe = "python" }
}
if (-not $PyExe) {
    Write-Error "Не найден Python 3.10+. Установи: winget install Python.Python.3.12"
    exit 1
}
$pyVer = & $PyExe @PyArgs --version
Write-Host "[setup-graphify] python: $PyExe $($PyArgs -join ' ') ($pyVer)"

# Канонический путь python.exe — его кладём в .mcp.json (надёжнее, чем 'py')
$PythonExe = (& $PyExe @PyArgs -c "import sys; print(sys.executable)").Trim()

# -- 2. graphifyy + mcp ---------------------------------------------------
Write-Host "[setup-graphify] установка graphifyy + mcp..."
& $PyExe @PyArgs -m pip install -q graphifyy mcp

# -- 3. skill (идемпотентно) ---------------------------------------------
try { & $PyExe @PyArgs -m graphify install } catch { }

# -- 4. Начальный граф (AST-only, с нуля) --------------------------------
Write-Host "[setup-graphify] построение графа (AST, без LLM)..."
try {
    & $PyExe @PyArgs (Join-Path $ScriptDir "_graphify_bootstrap.py")
    Write-Host "[setup-graphify] граф построен."
} catch {
    Write-Warning "AST-сборка не удалась — запусти '/graphify .' из Claude Code."
}

# -- 5. Git-хуки ----------------------------------------------------------
# Баг с '@' в allowlist — чисто homebrew'ный (python@3.12), на Windows
# не встречается, так что патч не нужен. Просто ставим.
try { & $PyExe @PyArgs -m graphify hook install } catch { }
Write-Host "[setup-graphify] хуки установлены."

# -- 6. .mcp.json (прямые слеши, чтобы не экранировать в JSON) -----------
$GraphJson = (Join-Path $ProjectRoot "graphify-out\graph.json") -replace '\\','/'
$CmdPath   = $PythonExe -replace '\\','/'
$mcp = @"
{
  "mcpServers": {
    "graphify": {
      "command": "$CmdPath",
      "args": [
        "-m",
        "graphify.serve",
        "$GraphJson"
      ]
    }
  }
}
"@
Set-Content -Path (Join-Path $ProjectRoot ".mcp.json") -Value $mcp -Encoding utf8
Write-Host "[setup-graphify] .mcp.json создан (command=$CmdPath)"

Write-Host ""
Write-Host "[setup-graphify] Готово. Дальше:"
Write-Host "  1. Перезапусти Claude Code в проекте — подхватит .mcp.json."
Write-Host "  2. Для богатого семантического графа: '/graphify . --mode deep' из Claude Code."
