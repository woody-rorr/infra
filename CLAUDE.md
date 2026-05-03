# 인프라 (Terraform)

## 구조
```
terraform/
├── modules/       ← 재사용 모듈 (VPC, RDS, ECS 등)
│   ├── vpc/       ← VPC, 서브넷, IGW
│   ├── ecr/       ← ECR 레포 3개 (db-schema, business-logic, api-endpoints)
│   ├── iam/       ← ECS Task Execution Role
│   ├── rds/       ← RDS PostgreSQL Free Tier (db.t3.micro)
│   └── ecs/       ← ECS Fargate 클러스터 + 서비스 3개 + cloudflared 사이드카
├── staging/       ← 스테이징 환경
└── production/    ← 프로덕션 환경
```

## 원칙
- `modules/` 는 레고 블록 — 직접 apply 금지, staging/production에서 호출
- **현재는 staging(테스트) 환경만 작업할 것 — production 절대 건드리지 말 것**
- **AWS Free Tier 범위만 사용할 것 — 유료 리소스 생성 금지**
  - ECS Fargate: CPU 256 / Memory 512 이하
  - RDS: db.t3.micro, 20GB gp2, 단일 AZ
  - 그 외 NAT Gateway, ALB, ElastiCache 등 유료 서비스 추가 금지
- **Free Tier 초과 리소스가 필요한 경우 반드시 사용자에게 먼저 알리고 승인받을 것**
  - tf 파일 작성 전에 "이 리소스는 Free Tier 대상이 아니며 비용이 발생합니다" 고지
  - 배포(terraform apply) 전에도 동일하게 경고 후 진행
- staging 먼저 apply → 검증 후 production 적용
- state 파일은 S3 + DynamoDB 락 (팀 공유) — staging/main.tf 내 backend 블록 주석 해제 후 사용

## AWS 계정 / 프로파일
| 프로파일 | 계정 ID | 용도 |
|---|---|---|
| `rorr-dev` | `239460481239` | 테스트/스테이징 |
| `lol-auth` / `default` | `805918413597` | 운영 (현재 동일 계정) |

## 배포 순서 (staging 기준)

### 1. 사전 준비
```bash
# DB 패스워드 환경변수 등록 (터미널 세션에 1회)
export TF_VAR_db_password="원하는패스워드"
```

### 2. Terraform — 인프라 생성
```bash
cd infra/terraform/staging
terraform init        # 최초 1회
terraform plan        # 어떤 리소스가 만들어지는지 확인
terraform apply       # yes 입력 → 약 15분 소요
```

생성 순서 및 소요 시간:
- VPC, 서브넷, IGW → ~1분
- ECR 레포 3개, IAM Role → ~1분
- RDS PostgreSQL → ~10분 (제일 오래 걸림)
- ECS 클러스터 + 서비스 3개 → ~2분

### 3. MCP 서버 이미지 빌드 & ECS 배포
```bash
bash mcp-servers/deploy-fargate.sh
# AWS_PROFILE=rorr-dev 로 ECR 푸시 → ECS 강제 재배포
```

### 4. cloudflared 터널 URL 확인
```bash
aws logs tail /ecs/mcp-agents-staging --profile rorr-dev --follow | grep trycloudflare.com
```
출력된 URL을 `v1/.mcp.json` 에 입력

### 5. 헬스체크
```bash
curl https://<cloudflare-url>/health
```

## 아키텍처 개요
```
Claude Code (.mcp.json)
      ↓ SSE 연결
cloudflared (HTTPS 터널, 무료)
      ↓
ECS Fargate Cluster (us-east-1)
  ├── db-schema Service     ← RDS 연결 (describe_table 실제 조회)
  ├── business-logic Service
  └── api-endpoints Service
      ↓
RDS PostgreSQL (프라이빗 서브넷, db.t3.micro Free Tier)
```

## 네트워크 구조
- VPC CIDR: `10.0.0.0/16`
- 퍼블릭 서브넷 (10.0.0.x, 10.0.1.x) → ECS 태스크
- 프라이빗 서브넷 (10.0.10.x, 10.0.11.x) → RDS
- RDS 보안그룹: ECS 보안그룹에서만 5432 허용

## 태깅 전략
`provider default_tags` 로 모든 리소스에 자동 적용:
```
Project     = mcp-agents
Environment = staging
ManagedBy   = terraform
Owner       = rorr-dev
```
AWS 콘솔에서 `Project = mcp-agents` 태그 필터로 이번 배포 리소스만 확인 가능

## 스케일 아웃
ECS 서비스별 독립 Auto Scaling — CPU 70% 초과 시 자동 증설 (최대 5 Task)
```bash
# 수동 스케일 아웃 (특정 서비스만)
aws ecs update-service \
  --cluster mcp-agents-staging-cluster \
  --service mcp-agents-staging-db-schema \
  --desired-count 3 \
  --profile rorr-dev
```

## 하네스: Terraform TDD

**목표:** Terraform 코드를 Depth 1(모듈) → Depth 2(통합) 두 단계로 검증

**트리거:** "테라폼 테스트", "tf 검증", "모듈 검증", "staging 배포 전 확인", "인프라 TDD" 관련 요청 시 `tf-tdd` 스킬을 사용하라.

**상세 가이드:** `infra/tdd/README.md`

**변경 이력:**
| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-05-01 | 초기 구성 | 전체 | Terraform TDD 하네스 신규 구축 |

---

## ⛔ 배포 전 필수 체크 (매번, 예외 없음)

```bash
# 반드시 이 계정이어야 함 — 다른 계정이면 즉시 중단
aws sts get-caller-identity --profile rorr-dev
# 기대값: Account 239460481239 / user woody
```

| 체크 항목 | 기대값 | 실패 시 |
|---|---|---|
| AWS 프로파일 | `rorr-dev` / Account `239460481239` | 즉시 중단 |
| 운영 계정 여부 | `805918413597` 와 다름 | 즉시 중단 |
| TF_VAR_db_password | 비어있지 않음 | export 후 재시도 |
| terraform init | `.terraform/` 존재 | init 실행 |

## 주의
- production apply 전 반드시 `terraform plan` 결과 확인
- 보안 그룹, IAM 변경은 백엔드 팀에 사전 공유
- cloudflared 터널 URL은 컨테이너 재시작 시 변경됨 → `.mcp.json` 재업데이트 필요
- RDS는 프라이빗 서브넷 → 로컬에서 직접 접속 불가 (ECS 통해서만 접근)
