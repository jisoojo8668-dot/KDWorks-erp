#!/usr/bin/env bash
# PostToolUse: AI가 파일을 고친 직후 자동 포맷 + 빠른 규칙 검사, 위반이면 AI에게 즉시 되돌려줌
set -uo pipefail
INPUT="$(cat)"
command -v jq >/dev/null || exit 0

FILE="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"
{ [ -z "$FILE" ] || [ ! -f "$FILE" ]; } && exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

run_arch() {
  if ! out="$(bash "$ROOT/scripts/check-arch.sh" 2>&1)"; then
    echo "$out" >&2
    exit 2
  fi
}

case "$FILE" in
  *.go)
    command -v gofmt >/dev/null && gofmt -w "$FILE"
    command -v goimports >/dev/null && goimports -w "$FILE"
    run_arch ;;
  *.ts|*.tsx|*.css)
    if [ -x "$ROOT/web/node_modules/.bin/prettier" ]; then
      "$ROOT/web/node_modules/.bin/prettier" --write "$FILE" >/dev/null 2>&1
    fi ;;
  *.sql)
    run_arch ;;
esac
exit 0
