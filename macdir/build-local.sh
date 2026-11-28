#!/bin/bash
# Локальная сборка ad-hoc кандидата diakitw (НЕ релиз, без Developer ID).
# Отличие от ci-build.sh: шаги идут в терминале, поэтому виден вывод, работает
# Ctrl-C, а stdin закрыт — шаг не может молча ждать ответа.
set -uo pipefail
cd "$(dirname "$0")"

CHECK_ONLY=""
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

mkdir -p evidence/diakitw-1.1.1
LOG="evidence/diakitw-1.1.1/local-build.log"
: > "$LOG"

say() { printf '%s\n' "$*" | tee -a "$LOG"; }

step() {
  local name="$1"; shift
  local start=$SECONDS
  say ""
  say "=== [$(date '+%H:%M:%S')] $name ==="
  # Важно: никакого фона и никакого tail — шаг работает в терминале как обычная
  # команда, поэтому Ctrl-C прерывает его сразу. </dev/null исключает скрытое
  # ожидание ввода (лицензия Xcode, пароль, системный диалог).
  if "$@" </dev/null 2>&1 | tee -a "$LOG"; then
    say "=== $name: готово за $((SECONDS - start))s"
  else
    local code=${PIPESTATUS[0]:-$?}
    say "!!! $name: ошибка (код $code), прошло $((SECONDS - start))s"
    return "$code"
  fi
}

say "diakitw — локальная сборка ad-hoc кандидата (не релиз)"
say "Каталог: $PWD"
say "Лог:    $PWD/$LOG"
say "Остановить сборку: Ctrl-C.  Проверка инструментов без сборки: bash build-local.sh --check"

[[ "$(uname -m)" == arm64 ]] || { say "ОШИБКА: нужен Apple Silicon, сейчас $(uname -m)"; exit 2; }
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null)}"
[[ -n "${DEVELOPER_DIR:-}" && -d "$DEVELOPER_DIR" ]] || {
  say "ОШИБКА: Xcode не найден. Установите Xcode и выполните: sudo xcode-select -s /Applications/Xcode.app"
  exit 2
}
say "Xcode: $DEVELOPER_DIR"

step "xcodebuild -version" xcodebuild -version || {
  say "Если произошла остановка здесь — не принята лицензия Xcode: sudo xcodebuild -license accept"
  exit 3
}
step "swift --version" swift --version || exit 3
step "SDK path" xcrun --sdk macosx --show-sdk-path || exit 3
step "python3 --version" python3 --version || exit 3

if [[ -n "$CHECK_ONLY" ]]; then
  say ""
  say "Инструменты в порядке. Сборка запускается той же командой без --check."
  exit 0
fi

export MACOSX_DEPLOYMENT_TARGET=14.0
export MACDIR_SIGNING_MODE=adhoc
# build.sh разрешает ad-hoc только при GITHUB_ACTIONS=true — тот же ключ, что в CI.
# Результат остаётся кандидатом в dist/*-unsigned-*, публикации не происходит.
export GITHUB_ACTIONS=true
export GITHUB_WORKSPACE="$(cd .. && pwd)"
export GITHUB_SHA="$(git -C .. rev-parse HEAD 2>/dev/null || echo local)"
export MACDIR_OUTPUT=dist/diakitw-1.1.1-unsigned-arm64
export MACDIR_TEST_SCRATCH="$GITHUB_WORKSPACE/.ci-scratch"
mkdir -p "$MACDIR_TEST_SCRATCH"
export TMPDIR="$(cd "$MACDIR_TEST_SCRATCH" && pwd -P)"

if [[ -e "$MACDIR_OUTPUT" || -e dist/diakitw-1.1.1-macos-unsigned-arm64.dmg ]]; then
  say "ОШИБКА: артефакты прошлого запуска уже есть. Удалите dist/diakitw-1.1.1* и повторите."
  exit 4
fi

step "сборка arm64 и все гейты (build.sh)" bash build.sh || {
  say "Смотрите шаг build.sh в $PWD/$LOG"; exit 5
}
step "кросс-сборка Intel (swift build --triple x86_64)" \
  swift build --jobs 2 --build-system native -c release \
    --scratch-path .build-diakitw-intel --triple x86_64-apple-macosx14.0 \
    --sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -Xswiftc -file-prefix-map -Xswiftc "$PWD=/diakitw-src" \
    -Xswiftc -debug-prefix-map -Xswiftc "$PWD=/diakitw-src" || {
  say "Смотрите шаг Intel в $PWD/$LOG"; exit 6
}
step "упаковка DMG (hdiutil)" python3 package-diagnostics-dmg.py || {
  say "Смотрите шаг упаковки в $PWD/$LOG"; exit 7
}
step "проверка артефактов" python3 Tests/verify_ci_artifacts.py || {
  say "Смотрите шаг проверки в $PWD/$LOG"; exit 8
}

say ""
say "ГОТОВО. Содержимое dist/:"
ls -1 dist 2>/dev/null | tee -a "$LOG"
say "Приложение: $PWD/$MACDIR_OUTPUT/diakitw.app"
