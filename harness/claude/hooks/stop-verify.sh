#!/usr/bin/env bash
# Stop: AI가 "끝났다"고 하기 전에 make check 실행. 실패하면 멈추지 못하게 하고 오류를 되돌려줌.
set -uo pipefail
INPUT="$(cat)"
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$ROOT"

# 무한 반복 방지: 이미 Stop 훅으로 재작업 중이면 통과
if command -v jq >/dev/null && [ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

# 코드 변경이 없으면 검사 생략
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -z "$(git status --porcelain -- cmd internal db web 2>/dev/null)" ]; then
    exit 0
  fi
fi

if ! out="$(make check 2>&1)"; then
  echo "make check 실패 — 아래 오류를 고친 뒤 완료하세요:" >&2
  echo "$out" | tail -60 >&2
  exit 2
fi
exit 0
