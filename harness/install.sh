#!/usr/bin/env bash
# 하네스 설치: harness/claude/ → .claude/ 로 복사하고 실행 권한 부여
# 사용: 프로젝트 루트에서  bash harness/install.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p .claude/hooks
cp harness/claude/settings.json.txt .claude/settings.json
cp harness/claude/hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh scripts/*.sh

# git 훅: 커밋 전에도 같은 검사 (사람 개발자용)
if [ -d .git ]; then
  cp harness/git/pre-commit .git/hooks/pre-commit
  chmod +x .git/hooks/pre-commit
  echo "✅ git pre-commit 훅 설치"
else
  echo "ℹ️  .git 없음 — 'git init' 후 다시 실행하면 pre-commit 훅도 설치됩니다"
fi

for t in jq go golangci-lint goimports sqlc goose; do
  command -v "$t" >/dev/null || echo "⚠️  $t 미설치 (brew install $t 또는 go install)"
done
echo "✅ 하네스 설치 완료 (.claude/settings.json, .claude/hooks/)"
