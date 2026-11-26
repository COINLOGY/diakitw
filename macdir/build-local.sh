#!/bin/bash
# Локальная сборка ad-hoc кандидата diakitw (НЕ релиз, без Developer ID).
# Отличие от ci-build.sh: каждый шаг печатает прогресс и ограничен по времени,
# поэтому терминал не может «зависнуть» молча.
set -uo pipefail
cd "$(dirname "$0")"

STEP_LIMIT="${STEP_LIMIT:-2400}"   # 40 минут на шаг, меняется: STEP_LIMIT=5400 bash build-local.sh
mkdir -p evidence/diakitw-1.0.7
LOG="evidence/diakitw-1.0.7/local-build.log"
: > "$LOG"

say() { printf '%s\n' "$*" | tee -a "$LOG"; }

run_step() {
  local name="$1"; shift
  local start=$SECONDS
  say ""
  say "=== [$(date '+%H:%M:%S')] $name ==="
  { "$@" 2>&1 | tee -a "$LOG"; } &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    sleep 10
    if kill -0 "$pid" 2>/dev/null; then
      printf '    ... %s: %ds\n' "$name" "$((SECONDS - start))"
    fi
    if (( SECONDS - start > STEP_LIMIT )); then
      say "!!! $name не уложился в ${STEP_LIMIT}s — прерываю"
      pkill -P "$pid" 2>/dev/null || true
      kill "$pid" 2>/dev/null || true
      return 124
    fi
  done
  wait "$pid" || return $?
  say "=== $name: готово за $((SECONDS - start))s ==="
}

say "diakitw — локальная сборка ad-hoc кандидата (не релиз)"
say "Рабочий каталог: $PWD"
say "Лог: $PWD/$LOG"
say "Лимит шага: ${STEP_LIMIT}s"

[[ "$(uname -m)" == arm64 ]] || { say "ОШИБКА: нужен Apple Silicon, сейчас $(uname -m)"; exit 2; }
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null)}"
[[ -n "${DEVELOPER_DIR:-}" && -d "$DEVELOPER_DIR" ]] || {
  say "ОШИБКА: Xcode не найден. Установите Xcode, затем: sudo xcode-select -s /Applications/Xcode.app"
  exit 2
}
export MACOSX_DEPLOYMENT_TARGET=14.0
export MACDIR_SIGNING_MODE=adhoc
# build.sh разрешает ad-hoc только при GITHUB_ACTIONS=true — тот же ключ, что в CI.
# Результат остаётся кандидатом в dist/*-unsigned-*, публикации не происходит.
export GITHUB_ACTIONS=true
export GITHUB_WORKSPACE="$(cd .. && pwd)"
export GITHUB_SHA="$(git -C .. rev-parse HEAD 2>/dev/null || echo local)"
export MACDIR_OUTPUT=dist/diakitw-1.0.7-unsigned-arm64
export MACDIR_TEST_SCRATCH="$GITHUB_WORKSPACE/.ci-scratch"
mkdir -p "$MACDIR_TEST_SCRATCH"
export TMPDIR="$(cd "$MACDIR_TEST_SCRATCH" && pwd -P)"

run_step "xcodebuild -version" xcodebuild -version || {
  say "Подсказка: остановка здесь обычно означает не принятую лицензию Xcode: sudo xcodebuild -license accept"
  exit 3
}
run_step "swift --version" swift --version || exit 3

if [[ -e "$MACDIR_OUTPUT" || -e "dist/diakitw-1.0.7-macos-unsigned-arm64.dmg" ]]; then
  say "ОШИБКА: артефакты прошлого запуска уже есть. Удалите dist/diakitw-1.0.7* и повторите."
  exit 4
fi

run_step "сборка arm64 и все гейты (build.sh)" bash build.sh || { say "Смотрите шаг build.sh в $PWD/$LOG"; exit 5; }
run_step "кросс-сборка Intel (swift build --triple x86_64)" \
  swift build --jobs 2 --build-system native -c release \
    --scratch-path .build-diakitw-intel --triple x86_64-apple-macosx14.0 \
    --sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -Xswiftc -file-prefix-map -Xswiftc "$PWD=/diakitw-src" \
    -Xswiftc -debug-prefix-map -Xswiftc "$PWD=/diakitw-src" || { say "Смотрите шаг Intel в $PWD/$LOG"; exit 6; }
run_step "упаковка DMG (hdiutil)" python3 package-diagnostics-dmg.py || { say "Смотрите шаг упаковки в $PWD/$LOG"; exit 7; }
run_step "проверка артефактов" python3 Tests/verify_ci_artifacts.py || { say "Смотрите шаг проверки в $PWD/$LOG"; exit 8; }

say ""
say "ГОТОВО"
ls -lh dist/*.dmg 2>/dev/null | tee -a "$LOG"
say "Приложение: $PWD/$MACDIR_OUTPUT/diakitw.app"
say "Установка: см. шаг «Установка» в отчёте (ditto в /Applications, затем открыть из Finder)"
