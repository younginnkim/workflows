---
name: tas-appgen
description: "TAS 자동화 2단계(appgen) — ①의 IR을 실제 앱 소스에 연결해 위젯 정보를 확정하고 appgen 파일 + 계측 app_test.dart를 만든다. 사용 시점: IR을 실제 앱 위젯에 연결할 때. 호출: `/tas-appgen {① IR 파일 경로}` (예: `/tas-appgen output/tas-parse/TVDEVTC-74461.ir.yaml`) — 앱 repo 경로는 실행 중 물어본다. 선행: /tas-parse(①). 다음: /tas-tasgen(③)."
---

# /tas-appgen — ① IR → appgen_output + app_test.dart (Stage ②)

①이 "위젯 유추 금지"로 미뤄둔 구체화를 **실제 앱 소스를 보고** 끝낸다. 각 step의 action/expected를
concrete binding으로 해소하고, 그 위젯/property가 `getProperty`로 노출되도록 **app 측 계측 `app_test.dart`
(toStringMap)도 작성**한다. **소스로 확인되는 것만 — 애매하면 질문, 못 풀면 `unsupported`. 지어내지 않는다.**

처리 전 **반드시** `reference/appgen-schema.md`(출력 스키마 + 해소 절차 + app_test.dart 템플릿)를 읽는다.

## 입력 (시작 전 확보)

- **① IR + app-config 파일** — `/tas-parse`가 저장한 `output/tas-parse/<…>.ir.yaml` **경로(절대경로 권장)를 받아 읽는다**
  (맨 위 `app:` 블록 = app-config, 그 아래 = IR). 경로를 안 주면 cwd의 `output/tas-parse/`에서 찾거나 사용자에게 묻는다.
  경로 대신 본문을 직접 받으면 그대로 사용.
- **app repo 경로** — **시작 시 사용자에게 AskUserQuestion로 묻는다**.:
  받은 경로의 `lib/`(+ 기존 `integration_test/app_test.dart`)를 읽어 해소한다.
  경로를 못 주거나 특정 부분이 소스로 안 잡히면 → **그 부분만** 사용자에게 직접 입력받는다.

## 처리

1. **app repo 확보** — 경로를 받고(없으면 요청) `lib/`를 스캔.
2. **target action 해소** — IR `steps[]`를 순회하며 각 step의 `actions` 중
   find/focus_move/tap/scroll/read_property를 `{step_id, action_id, typeName, find:{method,value,index?}}`.
   method: `match.key`→`byKey`, 보이는 텍스트→`byText`, 위젯 클래스→`byTypeName`. **소스에서 확인.**
   (preconditions는 top-level/step별 모두 binding 대상 아님.)
3. **expected 해소** — 각 step의 `expected` 항목마다 `{step_id, expected_index, kind, ...}`:
   app_launch→`appId` / property_value→`typeName,key,op,value(,group)` /
   widget_visible→`typeName(,where)` / 다중 OR→`any_present.options[]`.
4. **widgets contract** — 쓰인 TypeName → getProperty로 노출할 property key. 소스에서 위젯 필드 확인
   (presence만 필요하면 빈 리스트). 각 위젯 클래스의 **정의 파일 경로도 기록**(아래 매퍼 import용).
5. **app_test.dart 생성 (계측)** — `widgets`의 각 TypeName에 대해 `to<TypeName>(Widget w)` 매퍼 작성
   (`if (w is <TypeName>) properties['<key>'] = w.<소스에서 본 필드>;`), `printProperties` 맵에 전부 등록,
   `testWebosApplication(..., flagFileName: <app.flag_file>, toStringMap: printProperties)`로 노출.
   위젯 클래스를 `import`(4에서 기록한 경로 → `package:<pkg>/...`). **presence-only 위젯도 빈 매퍼로 등록**
   (getProperty가 카운트하게). 템플릿·예시는 `reference/appgen-schema.md`.
   → **입력받은 app repo의 `integration_test/app_test.dart`를 직접 수정**한다(별도 산출 파일 아님):
     기존 매퍼는 보존하고, 매퍼·`printProperties`·`testWebosApplication(..., toStringMap:)` 인자를 추가/활성화.
6. **애매/미발견 → 질문(항상 `AskUserQuestion`)** — repo 후보 여럿이면 `AskUserQuestion`(옵션 ≥2). 자유값
   (appId·shelfId 등 **누락값**)도 **반드시 `AskUserQuestion`**으로 묻는다 — 알 만한 후보를 옵션으로 제시하고
   사용자는 Other로 자유 입력. **평문 텍스트로 묻지 않는다.** 끝까지 못 풀면 `unsupported`에 사유.
7. **저장 + 출력** — `appgen_output`(app+widgets+bindings+unsupported)을 **cwd 기준 `output/tas-appgen/`에
   저장**한다: `output/tas-appgen/<source_ticket>.appgen.yaml` (ticket 없으면 `<test_case_id>.appgen.yaml`) —
   ①의 IR과 동일한 ticket/test_case_id·`pwd` 규칙(③이 경로로 읽게). 디렉터리가 없으면 만든다.
   저장 **절대경로와 내용**을 보여준다. app_test.dart는 5에서
   **repo에 직접 반영됨**. "③ `/tas-tasgen`에 IR 파일 + 이 appgen 파일 경로를 넘기고, ④에서 app을 빌드" 안내.

## 원칙

- **소스로 확인되는 것만.** 위젯/property/appId/필드를 지어내지 말 것 — 애매하면 사용자에게.
- **사용자에게 묻는 모든 것(누락값 포함)은 항상 `AskUserQuestion`으로** — 평문 텍스트 질문 금지.
- `bindings[].typeName`은 `widgets`에 있고, 참조 property key는 `widgets[typeName]`에 노출(=app_test.dart
  매퍼에 실제로 있음)돼야 한다.
- bespoke(루프·셸·멀티앱·OR 미해소)는 `unsupported`로 → ③ escalate.
