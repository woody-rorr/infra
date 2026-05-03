# Terraform TDD 가이드

## 두 Depth 구조

```
Depth 1 (모듈 단위)          Depth 2 (통합)
─────────────────────        ──────────────────────────
modules/vpc    → validate    staging/ plan (전체)
modules/iam    → validate         ↓ 사용자 승인
modules/ecr    → validate    staging/ apply
modules/rds    → plan             ↓
modules/ecs    → plan        AWS CLI 리소스 검증
     ↓                            ↓
  전부 통과 시만 →          cloudflared URL 확인
```

**Depth 1 실패 시 Depth 2 진행 금지.**

---

## 실행 방법

### 전체 실행 (Depth 1 + 2)
Claude Code에서:
```
/tf-tdd
```

### Depth 1만 (모듈 검증만)
```
테라폼 모듈 검증만 해줘
```

### Depth 2만 (통합, Depth 1 이미 통과 시)
```
staging 통합 테스트 실행해줘
```

---

## 사전 조건

```bash
# 1. AWS 인증 확인
aws sts get-caller-identity --profile rorr-dev

# 2. DB 패스워드 환경변수
export TF_VAR_db_password='패스워드'

# 3. Terraform 초기화 (최초 1회)
cd infra/terraform/staging && terraform init
```

---

## 에이전트 구성

| 에이전트 | 역할 | Depth |
|---|---|---|
| `tf-module-validator` | 모듈별 validate/plan | 1 |
| `tf-integration-tester` | 전체 plan/apply/검증 | 2 |

에이전트 정의: `.claude/agents/tf-module-validator.md`, `.claude/agents/tf-integration-tester.md`
오케스트레이터 스킬: `.claude/skills/tf-tdd/SKILL.md`

---

## 결과 확인

실행 후 결과는 `infra/tdd/last-result.md` 에 자동 저장됩니다.

---

## Free Tier 기준

| 리소스 | 허용 범위 |
|---|---|
| ECS Fargate | CPU 256 / Memory 512 이하 |
| RDS | db.t3.micro, 20GB gp2, 단일 AZ |
| ECR | 500MB/월 무료 |
| CloudWatch Logs | 5GB/월 무료 |
| NAT Gateway | **사용 금지** (유료) |
| ALB | **사용 금지** (유료) |
