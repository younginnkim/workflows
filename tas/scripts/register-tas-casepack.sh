#!/usr/bin/env bash
set -euo pipefail

# TAS workflow CasePack 등록 스크립트
# 사용법:
#   ./scripts/register-tas-casepack.sh <username> <password> [--dry-run]
#
# 옵션:
#   --dry-run  실제 등록 없이 payload 미리보기

HUB_URL="${HUB_URL:-http://10.157.71.52:5000}"
AUTHOR="${AUTHOR:-younginn.kim}"
TEAM="${TEAM:-webOS UX플랫폼개발팀}"
REPO_URL="${REPO_URL:-https://github.com/younginnkim/workflows}"
REPO_BRANCH="${REPO_BRANCH:-main}"
REPO_PATH="${REPO_PATH:-tas}"

usage() {
  cat <<USAGE
Usage: $0 <username> <password> [--dry-run]

Environment overrides:
  HUB_URL      (default: ${HUB_URL})
  AUTHOR       (default: ${AUTHOR})
  TEAM         (default: ${TEAM})
  REPO_URL     (default: ${REPO_URL})
  REPO_BRANCH  (default: ${REPO_BRANCH})
  REPO_PATH    (default: ${REPO_PATH})
USAGE
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

USERNAME="$1"
PASSWORD="$2"
DRY_RUN="${3:-}"

if [[ -n "$DRY_RUN" && "$DRY_RUN" != "--dry-run" ]]; then
  echo "Unknown option: $DRY_RUN"
  usage
  exit 1
fi

COOKIE_JAR="$(mktemp)"
PAYLOAD_FILE="$(mktemp)"
trap 'rm -f "$COOKIE_JAR" "$PAYLOAD_FILE"' EXIT

read -r -d '' GUIDE_DOC <<'MD' || true
# TAS 워크플로우 셋업 가이드

## 개요

TAS(Test Automation Script) workflow는 Zephyr TC(또는 시나리오 텍스트) 하나로
아래 4단계를 자동으로 연결해 webOS Flutter 앱 통합 테스트를 생성/검증합니다.

1. /tas-parse: TC를 semantic IR(YAML)로 변환
2. /tas-appgen: IR + 앱 소스 분석으로 widget binding/app_test 계측 생성
3. /tas-tasgen: IR + appgen 결과로 Python TAS 스크립트 생성
4. /tas-verify: TV에 빌드/배포/실행 후 PASS/FAIL 판정

## 빠른 사용

### 전체 자동 실행 (권장)

```bash
/tas TVDEVTC-23796
```

### 단계별 실행

```bash
/tas-parse TVDEVTC-23796
/tas-appgen output/tas-parse/TVDEVTC-23796.ir.yaml
/tas-tasgen output/tas-parse/TVDEVTC-23796.ir.yaml output/tas-appgen/TVDEVTC-23796.appgen.yaml
/tas-verify Functional/flutter/home/featureBAT/home_hero_banner_shown.py
```

## 산출물 경로

- parse: output/tas-parse/<TC_KEY>.ir.yaml
- appgen: output/tas-appgen/<TC_KEY>.appgen.yaml
- tasgen: <automation-tests>/Functional/flutter/<app>/featureBAT/*.py
- verify: tas-verify.sh 실행 로그 + PASS/FAIL 요약

## 선행 조건

- Claude Code에서 TAS skills 사용 가능
- app repo 경로(lib/, integration_test/app_test.dart 접근 가능)
- automation-tests(TAS) repo 경로(Functional/ 존재)
- verify 단계는 연결된 webOS TV 필요

## 참고

- repo path: ${REPO_PATH}
- verify는 번들 tas-verify.sh를 사용해 기계 절차를 결정론적으로 수행
MD

export GUIDE_DOC AUTHOR TEAM REPO_URL REPO_BRANCH REPO_PATH

python3 - "$PAYLOAD_FILE" <<'PY'
import json
import os
import sys

guide_doc = os.environ["GUIDE_DOC"].replace("${REPO_PATH}", os.environ["REPO_PATH"])

payload = {
    "title": "TAS Workflow — Zephyr TC 하나로 parse→appgen→tasgen→verify 자동화",
    "summary": "webOS Flutter 앱의 Zephyr TestCase(또는 시나리오 텍스트)를 입력받아 semantic IR 생성, 앱 계측, Python TAS 스크립트 생성, TV 검증까지 4단계를 자동 연결하는 Claude Code workflow입니다.",
    "platform": "webOS",
    "problem_statement": "webOS Flutter 앱 통합 테스트를 수동으로 작성/실행할 때, Zephyr TC 해석·위젯 탐색·스크립트 작성·TV 검증이 분리되어 반복 작업과 오류 가능성이 커지고 테스트 사이클이 길어집니다.",
    "solution_approach": "TAS workflow는 /tas 오케스트레이터와 4개 단계 스킬(/tas-parse, /tas-appgen, /tas-tasgen, /tas-verify)을 통해 TC 입력부터 TV PASS/FAIL 판정까지를 표준화합니다. parse는 IR을 생성하고, appgen은 실제 앱 소스 기반 바인딩을 해소하며, tasgen은 per-step Python TAS를 생성하고, verify는 번들 tas-verify.sh로 결정론 실행합니다.",
    "tags": [
        "workflow",
        "TAS",
        "webOS",
        "Flutter",
        "Zephyr",
        "claude-skill",
        "test-automation"
    ],
    "keywords": [
        "tas",
        "zephyr",
        "ir",
        "appgen",
        "tasgen",
        "verify",
        "webos",
        "flutter",
        "qa",
        "automation"
    ],
    "author": os.environ["AUTHOR"],
    "team": os.environ["TEAM"],
    "guide_document": guide_doc,
    "git_references": [
        {
            "repo_url": os.environ["REPO_URL"],
            "branch": os.environ["REPO_BRANCH"]
        }
    ]
}

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False)
PY

echo "=== TAS CasePack 등록 ==="
echo "서버: $HUB_URL"
echo "사용자: $USERNAME"

echo ""
echo "[0/3] Payload 검증"
python3 -m json.tool "$PAYLOAD_FILE" >/dev/null
echo "Payload JSON OK"

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo ""
  echo "[DRY RUN] 등록을 수행하지 않고 payload를 출력합니다."
  python3 -m json.tool "$PAYLOAD_FILE"
  exit 0
fi

echo ""
echo "[1/3] 로그인 중..."
LOGIN_RESP=$(curl -s -c "$COOKIE_JAR" -X POST "$HUB_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$LOGIN_RESP" | tail -1)
LOGIN_BODY=$(echo "$LOGIN_RESP" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "로그인 실패 (HTTP $HTTP_CODE)."
  echo "$LOGIN_BODY"
  exit 1
fi
echo "로그인 성공!"

echo ""
echo "[2/3] CasePack 등록 중..."
RESPONSE=$(curl -s -b "$COOKIE_JAR" -X POST "$HUB_URL/api/v1/casepacks/" \
  -H "Content-Type: application/json" \
  --data-binary @"$PAYLOAD_FILE")

echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

CASE_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('case_id', ''))" 2>/dev/null || true)

echo ""
if [[ -n "$CASE_ID" ]]; then
  echo "[3/3] 등록 완료!"
  echo "  CasePack ID: $CASE_ID"
  echo "  URL: $HUB_URL/casepacks/$CASE_ID"
else
  echo "[3/3] 등록 응답에서 case_id를 찾지 못했습니다."
  exit 1
fi
