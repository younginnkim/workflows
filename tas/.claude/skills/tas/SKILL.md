---
name: tas
description: "TAS 전체 자동화 — Zephyr TC 하나로 ①파싱→②appgen→③tasgen→④verify를 끝까지 자동 실행. 사용 시점: TAS 테스트를 처음부터 끝까지 자동으로 만들고 검증할 때. 호출: `/tas {Zephyr TC 키 또는 시나리오 텍스트}` (예: `/tas TVDEVTC-23796`). 한 단계만 돌리려면 /tas-parse·/tas-appgen·/tas-tasgen·/tas-verify를 직접 호출."
---

# /tas — 전체 워크플로우 오케스트레이터 (①→②→③→④)

Zephyr TC(또는 시나리오 텍스트) 하나로 **① 파싱 → ② appgen → ③ tasgen → ④ verify**를 끝까지 자동 진행한다.
각 단계는 **전용 스킬을 그대로 호출**한다(로직 재구현 금지). 산출물은 발동한 cwd의 `output/<스킬명>/`에 파일로 흐른다:
`output/tas-parse/<ticket>.ir.yaml` → `output/tas-appgen/<ticket>.appgen.yaml` → TAS repo 스크립트 → TV 검증.

## 0. 인테이크 — 시작 시 한 번에 모아 받기

끝까지 자동으로 돌리려면 **각 단계가 사람에게 묻는 값을 여기서 한 번에 받는다**(이후 단계엔 다시 안 묻게).
받은 값은 세션 동안 재사용한다. **모르면 묻고, 지어내지 않는다.**

- **TC source** — `/tas` 인자(Zephyr 키 예: `TVDEVTC-23796`, 또는 TC 시나리오 텍스트). 없으면 묻는다.
- **app-config 4필드**(①용) — `AskUserQuestion`으로: `sam_app_id` / `flutter_app_id` / `flag_file`
  / `base_class_name`(= `{app_id}TasBase`로 확정). 예시는 `/tas-parse` 인테이크 규칙 참고.
- **app repo 경로**(②용) — `lib/`(+ 기존 `integration_test/app_test.dart`)가 있는 곳.
- **automation-tests(TAS) repo 경로**(③용) — `Functional/`이 있는 곳.
- **추가 preconditions**(①용) — TC에서 읽은 것 외 사용자 추가분. 없으면 '없음'.
- **④ config** — `~/.tas/<appName>.conf`가 있으면 그대로, 없으면 위 app-config + repo 경로로 자동 생성되니
  여기서 따로 더 물을 것 없음(스크립트가 없는 값만 요구하면 그때 받는다).

## 실행 — 단계별 스킬 호출, 끝까지 자동

각 단계를 **해당 스킬로 호출**하고, 0단계에서 모은 입력 + **직전 단계가 저장한 산출 파일 경로**를 넘긴다.
각 단계가 자체 인테이크로 다시 묻지 않도록 0단계 값을 함께 전달한다.

1. **① `/tas-parse`** — TC + app-config → `output/tas-parse/<ticket>.ir.yaml`(맨 위 `app:` 블록 + IR).
2. **② `/tas-appgen`** — ①의 `ir.yaml` 경로 + app repo → `output/tas-appgen/<ticket>.appgen.yaml` + app repo의
   `integration_test/app_test.dart` 수정.
3. **③ `/tas-tasgen`** — ①`ir.yaml` + ②`appgen.yaml` 경로 + TAS repo → `Functional/flutter/<appName>/featureBAT/`에
   `<appName>_base.py` + step별 `<appName>_<step.name>.py`.
4. **④ `/tas-verify`** — app-config + repo 경로 + ③이 쓴 per-TC 스크립트 경로 → `tas-verify.sh` 실행 → 판정.

### 멈춤 조건 (이 셋에서만 멈춘다, 그 외엔 다음 단계로 바로)

- **① `unresolved`가 비어있지 않음** → ESCALATE. IR과 unresolved 항목을 보여주고 멈춰 사용자 확인.
- **② `unsupported`가 있음** → 해당 항목을 보여주고 멈춤(escalate). 나머지로 계속할지는 사용자에게.
- **④ 판정이 `❌ FAIL` 또는 `⚠️ 불명확`** → 스크립트 출력 로그를 그대로 보여주고, 원인이 ②(매퍼)인지
  ③(스크립트)인지 precondition(환경)인지 → **되돌릴 단계 안내** 후 멈춤.

위 조건이 아니면 각 단계 산출(파일 경로 포함)을 간단히 보고하고 **곧바로 다음 단계로** 넘어간다.

## 원칙

- **로직 재구현 금지.** 각 단계는 전용 스킬(`/tas-parse`·`/tas-appgen`·`/tas-tasgen`·`/tas-verify`)을 호출.
- **사람만 아는 값은 0단계에서 모아** 이후 단계로 자동 전달 — 단계마다 다시 묻지 않는다. 모르면 묻고 안 지어낸다.
- **사용자에게 묻는 모든 것(인테이크·누락값·escalate 선택 포함)은 항상 `AskUserQuestion`으로** — 평문 텍스트 질문 금지.
- **산출은 cwd `output/<스킬명>/`로 흐른다:** `output/tas-parse/<ticket>.ir.yaml` →
  `output/tas-appgen/<ticket>.appgen.yaml` → TAS repo 스크립트. 단계 간 핸드오프는 화면 출력이 아니라
  **저장된 파일 경로**로 한다.
