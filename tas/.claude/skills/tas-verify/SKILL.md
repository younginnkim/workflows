---
name: tas-verify
description: "TAS 자동화 4단계(verify) — ③이 만든 per-TC TAS 스크립트를 연결된 TV에 빌드·배포·실행해 PASS/FAIL을 판정한다(기계적 실행은 번들 tas-verify.sh가 처리). 사용 시점: 만든 TAS 스크립트를 실제 TV에서 검증할 때. 호출: `/tas-verify {③ per-TC 스크립트 경로}` (예: `/tas-verify .../featureBAT/home_hero_banner_shown.py`). 선행: /tas-tasgen(③)."
---

# /tas-verify — TV 빌드·배포·실행 검증 (Stage ④)

**기계적 실행은 추론하지 말 것.** TV 탐지·host-key·reboot·빌드·배포·실행은 전부
번들 스크립트 **`tas-verify.sh`**(이 SKILL.md와 같은 디렉토리)가 결정론적으로 처리한다.
에이전트가 직접 ssh/scp/스캔하거나 단계를 재구현하지 않는다 — 오직 아래 4가지만 한다.

## 1. config 확보
앱별 고정값은 `~/.tas/<appName>.conf`(앱당 1회). `<appName>` = `sam_app_id` 마지막 세그먼트(예: `home`).
- **있으면 그대로 사용.** 없으면 **① app-config + ②③ repo 경로(세션값)** 로 1회 생성:
  ```sh
  APP_REPO=<② app repo 절대경로>
  AUTOMATION_TESTS=<③ automation-tests 절대경로>
  FLAG_FILE=<app-config flag_file>
  FLUTTER_APP_ID=<app-config flutter_app_id>   # = --tas-service-name
  SAM_APP_ID=<app-config sam_app_id>            # TV의 앱 디렉토리명
  # SUBNET=192.168.0   # (선택) 미지정 시 PC 기본경로에서 유추
  ```
  세션에 없는 값만 사용자에게 묻는다(지어내지 않음).

## 2. TC 결정
③이 쓴 per-TC 경로(예: `Functional/flutter/home/featureBAT/<stem>.py`). 세션에 없으면 사용자에게 AskUserQuestion으로 반드시 묻는다.
**여러 TC를 한 번에** 검증할 수 있다 — `--tc`를 여러 번 준다.

## 3. 스크립트 실행 — A~D는 1회, E는 TC마다
빌드·배포·mount(A~D)는 **모든 TC가 공유**한다. TC마다 통째로 반복하면 안 된다(느리고, 중간에 끊기면 half-mount).
그래서 **A~D는 처음 1회만, 이후엔 `.py`만 갈아끼우며 E(qa-test-runner)만 반복**한다. 스크립트가 이 흐름을 내장한다.

**여러 TC를 한 호출로 (권장):** A~D 1회 → TC마다 E 실행 → 마지막에 전체 판정 요약.
```bash
<skill_dir>/tas-verify.sh --config ~/.tas/<appName>.conf \
  --tc <TC1> --tc <TC2> --tc <TC3> [옵션]
```
**이미 mount된 상태에서 E만 다시:** (앱 빌드/배포가 그대로일 때 — 같은 세션 재검증)
```bash
<skill_dir>/tas-verify.sh --config ~/.tas/<appName>.conf --exec-only --ip <IP> --tc <TC> [...]
```
옵션: `--ip <IP>`(자동탐지 건너뜀) · `--reuse`(빌드 C만 생략, 배포/mount는 함) · `--exec-only`(B·C·D 통째 생략, 기존 mount로 E만) · `--force-reboot` · `--dry-run`(명령만).
- 기본 = TV 자동탐지(webOS = `/usr/palm/applications/<sam_app_id>` 존재로 판별) + 빌드 + 조건부 reboot + 배포/mount + E.
- 스크립트는 A→B→C→D→`E[i/n]`(TC별) 단계를 순서대로 로그로 찍는다. **그 진행 출력을 사용자에게 step별로 그대로 보여준다** — grep으로 잘라내거나 배치로 숨기지 않는다. 백그라운드로 돌리지 말고(진행이 안 보임) 포그라운드로 실행.
- 스크립트가 비0으로 끝나면(=하나라도 FAIL) **그 출력(stderr 포함)을 그대로** 보여준다. 추측 금지.

스크립트 진행 상황을 사용자에게 보여주면서, **FAIL이면 원인(환경·스크립트·매퍼) 추측하지 말고, 사용자에게 선택지로 물어 안내한다**:

## 4. 판정
TC마다 `판정: ✅ PASS` / `❌ FAIL` / `⚠️ 불명확` 줄을, 여러 TC면 끝의 `전체 판정 요약`까지 **그대로** 전달. FAIL이면 출력 로그를 보여주고,
원인이 ②③ 산출(app_test.dart 매퍼 / TAS 스크립트)이거나 precondition(환경·화면 상태)이면 어느 단계로
되돌릴지 안내. TV 0대/복귀실패 등은 스크립트가 actionable 에러로 알려주므로 그대로 전달.

## 원칙
- **기계적 단계를 에이전트가 재구현·우회하지 않는다.** 전부 `tas-verify.sh`. 스킬은 입력·호출·판정만.
- 환경값은 config·세션 재사용, 모르면 질문 — 지어내지 않는다.
- **사용자에게 묻는 모든 것(누락 config·경로·TC 포함)은 항상 `AskUserQuestion`으로** — 평문 텍스트 질문 금지.
- 스크립트 실패 시 로그 그대로, 추측 금지.
