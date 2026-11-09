# KD기공 ERP — AI 작업 규칙

이 파일은 AI 코딩 에이전트(Claude 등)가 이 저장소에서 작업할 때 항상 먼저 읽는 규칙입니다.
사람 개발자에게도 같은 규칙이 적용됩니다.

## 프로젝트 한 줄 요약
건축물 기계설비·공조 시공사(KD기공)의 ERP. 핵심 가치는 **현장별 손익을 실시간으로 보이게 하는 것**.
상세 설계: `docs/01_ERP_기획설계서.md` (작업 전 관련 장을 반드시 읽을 것)

## 기술 스택
- 백엔드: Go 1.23+, chi 라우터, PostgreSQL 16, sqlc + pgx, goose 마이그레이션
- 프론트: React + TypeScript + Vite (`web/`), 빌드 결과는 Go `embed`로 실행 파일에 포함
- 배포(개발): AWS Lightsail 1대, Docker Compose, Caddy(HTTPS)

## 디렉터리
```
cmd/server/         진입점
internal/platform/  db, auth, config, logger, audit (공통)
internal/<모듈>/    mdm, sal, prj, mat, acc, hr, wf — 각 handler.go / service.go / repository.go
db/migrations/      goose 마이그레이션 (번호_설명.sql)
db/queries/<모듈>/  sqlc 쿼리
web/                React 앱
docs/               설계서, ADR(docs/adr)
```

## 반드시 지킬 규칙 (scripts/check-arch.sh 가 자동 검사)
1. **모듈 경계**: 모듈은 다른 모듈의 `service` 인터페이스만 호출한다. 다른 모듈의 repository·db 패키지를 import 하지 않는다.
2. **원가 원장 단일 진입점**: `cost_entry` 테이블에 쓰기는 `internal/acc` 와 `db/queries/acc` 에서만 한다. 다른 모듈은 `acc` 서비스의 `RecordCost(...)` 를 호출한다.
3. **금액은 정수**: 금액·단가에 `float32/float64` 금지. 원 단위 `int64` (DB `bigint`) 또는 `numeric` 사용. 수량은 `numeric` ↔ 문자열/decimal 타입.
4. **마이그레이션 불변**: 이미 커밋된 마이그레이션 파일은 수정하지 않는다. 변경은 새 마이그레이션 파일로 추가한다.
5. **현장 데이터 범위 권한**: 현장(project) 데이터를 조회하는 API는 반드시 사용자 데이터 범위 필터(`auth.ProjectScope`)를 거친다.
6. **감사 로그**: 금액·승인 상태를 바꾸는 서비스 함수는 `audit.Record(...)` 를 호출한다.
7. 비밀값(.env, 키)은 커밋·수정하지 않는다. 예시는 `.env.example` 에만.

## 작업 방식
1. 작업 전: 설계서 관련 장과 해당 모듈 코드를 읽고, 변경 계획을 짧게 먼저 말한다.
2. 작게 나눠서 구현한다 (한 번에 한 기능/한 테이블).
3. 서비스 로직에는 테이블 기반 단위 테스트를 같이 작성한다. 금액 계산(기성, 원가 집계, 소진율)은 경계값 테스트 필수.
4. 끝내기 전에 `make check` 를 실행하고 전부 통과해야 완료로 본다.
5. 설계상 중요한 결정(라이브러리 선택, 테이블 구조 변경)은 `docs/adr/` 에 ADR 로 남긴다.

## 명령어
- `make check` — 포맷·vet·lint·테스트·아키텍처 규칙 전체 검사 (완료 기준)
- `make test` — Go 테스트
- `make arch` — 아키텍처 규칙만 검사
- `make web-check` — 프론트 타입체크·린트·테스트
- `make migrate-new name=설명` — 새 마이그레이션 생성
- `make sqlc` — 쿼리 코드 생성

## 도메인 용어 (코드 이름 ↔ 업무 용어)
| 코드 | 업무 용어 |
|------|----------|
| project | 현장 |
| wbs | 공종 |
| cost_type: MAT/LAB/SUB/EXP | 재료비/노무비/외주비/경비 |
| budget_item | 실행예산 항목 |
| cost_entry | 원가 원장 |
| progress_billing | 기성 청구 |
| retention | 유보금 |
| daily_report | 작업일보 |
| subcontract | 외주(하도급) 계약 |
| estimate / estimate_item | 견적 / 내역 |

UI 문구와 에러 메시지는 한국어, 코드 식별자·주석은 영어 또는 한국어 모두 허용(일관성 유지).
