#!/usr/bin/env bash
# KD기공 ERP 아키텍처 규칙 검사 (CLAUDE.md "반드시 지킬 규칙" 참조)
# 사용: scripts/check-arch.sh   (위반 시 exit 1)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODULES="mdm sal prj mat acc hr wf"
FAIL=0
err() { echo "❌ [$1] $2"; FAIL=1; }

# Go 소스(테스트 제외 안 함 — 테스트도 규칙 준수)
go_files() { find internal cmd -name '*.go' 2>/dev/null; }

if [ -z "$(go_files)" ]; then
  echo "ℹ️  Go 소스가 아직 없습니다. 아키텍처 검사 건너뜀."
  exit 0
fi

MODPATH=""
if [ -f go.mod ]; then MODPATH="$(awk '/^module /{print $2; exit}' go.mod)"; fi

# 규칙 1: 모듈 경계 — 다른 모듈의 repository/db 하위 패키지 import 금지,
#          그리고 다른 모듈 루트 패키지는 service 인터페이스로만 사용(하위 패키지 import 금지)
for m in $MODULES; do
  [ -d "internal/$m" ] || continue
  for other in $MODULES; do
    [ "$m" = "$other" ] && continue
    hits=$(grep -rnE "\"[^\"]*internal/$other/[^\"]+\"" "internal/$m" --include='*.go' 2>/dev/null || true)
    if [ -n "$hits" ]; then
      err "모듈경계" "internal/$m 이 internal/$other 의 하위 패키지를 import 합니다 (service 인터페이스만 사용):"
      echo "$hits" | sed 's/^/     /'
    fi
  done
done

# 규칙 2: cost_entry 쓰기는 acc 모듈에서만
hits=$(grep -rniE "(insert[[:space:]]+into|update|delete[[:space:]]+from)[[:space:]]+cost_entry" \
        internal db/queries 2>/dev/null | grep -vE "^(internal/acc/|db/queries/acc/)" || true)
if [ -n "$hits" ]; then
  err "원가원장" "cost_entry 쓰기는 internal/acc, db/queries/acc 에서만 허용됩니다:"
  echo "$hits" | sed 's/^/     /'
fi

# 규칙 3: 금액에 float 금지 — 금액성 이름의 필드/변수가 float 타입이면 위반
hits=$(grep -rnE "(amount|price|cost|total|budget|balance|retention|금액|단가)[A-Za-z0-9_]*[[:space:]]+\*?float(32|64)" \
        -i internal cmd --include='*.go' 2>/dev/null || true)
if [ -n "$hits" ]; then
  err "금액타입" "금액·단가에 float 타입을 쓰면 안 됩니다 (int64 원 단위 또는 decimal 사용):"
  echo "$hits" | sed 's/^/     /'
fi
hits=$(grep -rniE "(amount|price|cost|total)[a-z0-9_]*[[:space:]]+(real|double precision|float)" \
        db/migrations 2>/dev/null || true)
if [ -n "$hits" ]; then
  err "금액타입" "마이그레이션에서 금액 컬럼에 real/double/float 를 쓰면 안 됩니다 (bigint 또는 numeric):"
  echo "$hits" | sed 's/^/     /'
fi

# 규칙 4: 커밋된 마이그레이션 수정 금지 (git 저장소일 때만)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git rev-parse HEAD >/dev/null 2>&1; then
  changed=$(git diff --name-only HEAD -- db/migrations 2>/dev/null; git diff --name-only --cached -- db/migrations 2>/dev/null)
  for f in $(echo "$changed" | sort -u); do
    if git cat-file -e "HEAD:$f" 2>/dev/null; then
      err "마이그레이션" "이미 커밋된 마이그레이션을 수정했습니다: $f (새 파일로 추가하세요)"
    fi
  done
fi

# 규칙 7: 비밀값 파일 추적 금지
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  secrets=$(git ls-files | grep -E '(^|/)\.env$|\.pem$|id_rsa' || true)
  [ -n "$secrets" ] && err "비밀값" "비밀값 파일이 git 에 포함되어 있습니다: $secrets"
fi

if [ "$FAIL" -ne 0 ]; then
  echo ""
  echo "아키텍처 규칙 위반이 있습니다. CLAUDE.md 의 '반드시 지킬 규칙'을 확인하세요."
  exit 1
fi
echo "✅ 아키텍처 규칙 통과"
