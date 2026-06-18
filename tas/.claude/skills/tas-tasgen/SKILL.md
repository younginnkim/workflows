---
name: tas-tasgen
description: "TAS 자동화 3단계(tasgen) — ①의 IR과 ②의 appgen 결과로 IR step마다 Python TAS 스크립트를 만들어 대상 TAS repo에 직접 쓴다. 사용 시점: IR+appgen을 실제 TAS 스크립트로 만들 때. 호출: `/tas-tasgen {① IR 파일 경로} {② appgen 파일 경로}` — TAS repo 경로는 실행 중 물어본다. 선행: /tas-appgen(②). 다음: /tas-verify(④)."
---

# /tas-tasgen — IR + appgen → Python TAS 스크립트 (stage③)

Claude Code 에이전트가 ① IR + ② appgen_output을 받아 **IR step마다** Python TAS 스크립트(+단일 meta base)를
**직접 작성해 대상 TAS repo에 반영**한다. ②가 TypeName/find/property를 다 풀어놨으므로 슬롯 채우기 — 새 판단 없음.

작성 전 **반드시** 읽는다(이 SKILL.md 기준 상대):
- `reference/tasgen-mapping.md` — dispatch 표 + 규칙 + 출력 레이아웃 + 예시.
- `reference/tasbase.py` — 호출 가능한 primitive 라이브러리(여기 `def`로 정의된 것만 쓴다).
  이 파일은 대상 repo로 복사되는 디바이스 측 산출물이다.

## 입력 (시작 전 확보)

- **① IR 파일 + ② appgen_output 파일** — `output/tas-parse/<…>.ir.yaml`(맨 위 `app:` 블록 = app-config) +
  `output/tas-appgen/<…>.appgen.yaml` **경로를 받아 읽는다**. 경로 대신 본문을 직접 받으면 그대로 사용.
- **반영할 TAS repo 경로** — **시작 시 사용자에게 AskUserQuestion로 묻는다**.:
  > "TAS 스크립트를 넣을 automation-tests repo 경로? (`Functional/`이 있는 곳)."
- **appName** = app-config `sam_app_id`의 마지막 세그먼트(예: `com.webos.app.home` → `home`).

## 실행

1. `reference/tasgen-mapping.md`의 **dispatch 표**대로 IR을 옮긴다. **IR `steps[]`의 각 step = 파일 1개**:
   그 step의 `actions`(id 오름차순) → 그 step의 `expected`를 `reference/tasbase.py` primitive 호출로.
   한 step의 actions/expected만 그 파일에 쓴다(다른 step과 섞지 않음 = 평탄화 금지).
2. 대상 repo의 **`Functional/flutter/<appName>/featureBAT/`** 에 직접 쓴다(라이선스 헤더 포함):
   - **base 파일 — `<snake_case(base_class_name)>.py`** (앱당 1개, 예: base_class_name `homeTasBase` → `home_tas_base.py`).
     `reference/tasbase.py` 본문을 그대로 쓰되 ① class명을 `<base_class_name>`으로, ② meta(`FLUTTER_APP_ID`/
     `SAM_APP_ID`/`FLAG_FILE`/`JIRA_ID`)·`test_name`을 app-config 값으로 채운다.
     (= 범용 primitive + 앱 meta가 **한 클래스에**. 별도 `tasbase.py` 안 만듦.)
     파일명을 **base_class_name에서 파생**하므로 골든 `<appName>_base.py`(예: home_base.py)와 자동으로 겹치지 않는다.
     **이미 있으면 재사용**(없으면 새로 생성 — golden home_base.py만 있고 이 base가 없으면 반드시 만든다). 그래도 충돌하면 다른 이름으로(사용자 확인).
   - **IR step마다 `<appName>_<stem>.py`** — stem = `<NN>_<step.name>` (NN = `step.id` 2자리 zero-pad, 1→`01`).
     얇은 `run_flutter_test` (예: step.id=1 → `home_01_hero_banner_shown.py`).
     클래스명 = `PascalCase(<appName>_<stem>)`(예: `Home01HeroBannerShown`), `test_name = '<appName>_<stem>'`.
   **import**: 각 step 파일은 `from Functional.flutter.<appName>.featureBAT.<snake_case(base_class_name)> import <base_class_name>`
   (예: `from Functional.flutter.home.featureBAT.home_tas_base import homeTasBase`).
3. 쓴 파일 경로(들)를 보여주고 "④ `/tas-verify`로 빌드·실행" 안내. bespoke/`unsupported`인 step은
   해당 step만 escalate 스텁 + 사람 확인(나머지 step은 정상 생성).

## 원칙

- `reference/tasbase.py`에 **있는 primitive만** 호출. property key는 `widgets[typeName]`에 있는 것만.
- bespoke(루프·셸·멀티앱·OR 미해소)·appgen `unsupported`는 코드 지어내지 말고 escalate.
- TypeName/property 해석은 ③ 책임 아님(②가 앱 소스에서 결정).
- **사용자에게 묻는 모든 것(repo 경로·누락값 포함)은 항상 `AskUserQuestion`으로** — 평문 텍스트 질문 금지.
