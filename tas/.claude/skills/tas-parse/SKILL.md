---
name: tas-parse
description: "TAS 자동화 1단계(파싱) — Zephyr TC를 받아 구조화된 테스트 명세(IR YAML)를 생성한다(②③④의 공통 입력). 사용 시점: TC로 IR만 만들 때. 호출: `/tas-parse {Zephyr TC 키 또는 시나리오 텍스트}` (예: `/tas-parse TVDEVTC-74461`). 다음: /tas-appgen(②)."
---

# /tas-parse — TC → semantic IR (Stage ①)

Jira Ticket을 받아 semantic IR(YAML)을 **생성**한다. 산출 IR은 ②③④의 공통 입력이 된다.
생성 전에 **반드시** `reference/ir-schema.md`(IR 스키마 + 생성 규칙 + grounding)를 읽는다.

## 입력 받기 (인테이크)

①은 두 묶음을 받는다 — **app-config(앱당 1회)** + **per-TC packet(TC마다)**. 
사람만 아는 정보를 여기서 전부 받는다(이후 단계가 추측하지 않게). 안 주면 요청한다 — **지어내지 않는다.**

### ① app-config — 입력으로 받는다(오케스트레이터 `/tas`가 0단계에서 모아 전달), 세션 내 재사용
app-config는 **입력으로 받는 것이 기본**이다(전체 워크플로우에선 `/tas`가 전달). 입력에 있으면 그대로 쓰고 묻지 않는다.
**단독 실행 등으로 app-config가 입력에 없을 때만 fallback으로** `AskUserQuestion` 도구로 아래 3가지를 한 항목씩 순서대로 물어 받는다.
예시를 질문에 포함해주고 다음을 질문 — 객관식인 경우 그대로 질문, 아닌 경우 "직접 입력"(사용자는 Other로 자유 입력):
  - `sam_app_id`(앱 id)     (예: com.webos.app.{app_id})
  - `flutter_app_id`(TAS용 앱 id) (예: com.webos.tas.{app_id})
  - `flag_file`(TAS 판별 flag 파일 경로) — "직접 입력"란 제외해줘
    - 대부분의 앱 기본 권장: /tmp/tas_enabled
    - 재부팅해도 유지되는 앱 (ex. home): /var/luna/preferences/tas_{app_id}_enabled

`base_class_name`는 (예: {app_id}TasBase) 으로 확정한다. app_id 대문자 형태로 작성(②에서 TAS 스크립트 클래스의 부모 클래스 이름으로 쓰임).
3개를 받으면 app-config를 확정하고 IR과 함께 ②로 넘긴다.

### ② per-TC packet — TC마다
```yaml
tc:
  source: Jira Ticket (예: TVDEVTC-74461) 또는 TC 텍스트
  preconditions:
    - # 이 TC에 필요한 사전조건(사람이 명시; TC 텍스트 보강용)
```
- `source`가 **Zephyr 키**면 `mcp__zephyr-tc__get_tc(key)`로 받아온다:
  - **ZAPI `steps[]`의 각 항목 = IR `steps[]`의 한 자기완결 시나리오.** 매핑:
    `step`→IR step의 `name`(snake_case 슬러그) + `actions`(intent/target), `expected`→그 step의
    `expected`, `data`→`target.match` 단서/`expected.params`. `steps` 비면 `description`/`raw_tc_text` 폴백.
  - `source_span`은 ZAPI **원문을 인용**.
- `source`가 **텍스트**면 그대로 사용.
- `preconditions` — **두 출처를 합쳐** 넣는다(각 항목 `source_span` 필수). **글로벌 vs step별로 나눈다:**
  1. **TC에서 읽은 것 (default 포함).** TC step의 `[pre-condition]`/`[test-sequence]` 등에서 명시된
     사전조건을 모두 추출해 기본 포함한다. `source_span` = TC 원문 인용. kind 매핑 & 배치:
     - 환경·설정 상태("network connected", "user agreements allowed", "ad setting on" 등) → `environment`
       (value=상태 서술). TC 전체 공통이므로 **top-level `preconditions`**에 둔다.
     - "앱을 실행한다 / foreground" → `app_lifecycle` value `resumed` (app=대상 appId). 그 시나리오가
       시작 상태로 요구하므로 **해당 step의 `preconditions`**에 둔다(여러 step이 각각 요구하면 각 step에).
     - 특정 위젯 포커스 → `focused` / 특정 property 상태 → `property_value` (해당 step에).
  2. **사용자 추가 입력.** TC에서 읽은 것들을 보여준 뒤, **`AskUserQuestion`으로 묻는다**(옵션: '없음' /
     '추가 있음'→Other 자유 입력; 평문 텍스트 질문 금지): "추가할 precondition 있으면 적어줘, 없으면 '없음'."
     → 사용자가 입력한 텍스트를 precondition으로 추가한다(글로벌이면 top-level, 특정 step이면 그 step).
       각 항목 `source_span` = 사용자 입력 인용. "없음"은 추가 안 함.
- 받은 내용이 너무 추상적이거나 MCP 실패면 → 사용자에게 TC 텍스트를 직접 AskUserQuestion 형태로 입력 요청.

## 실행

`reference/ir-schema.md`의 HARD RULES대로 한다.

1. **generate** — TC에서 IR을 만든다: 명시된 것만, TypeName 금지, 모든 항목에 verbatim
   `source_span`, 모호하면 `unresolved`. `target_app` = app-config의 `sam_app_id`.
   - **각 TC sub-check를 자기완결 `step`으로 분리**: `{id, name, preconditions, actions, expected}`.
     "버튼 선택" → 그 step의 `actions`에 `focus_move`+`key_press: OK`(원문 한 줄 공유).
   - 글로벌 환경 사전조건은 top-level `preconditions`, 시나리오 시작 상태(앱 실행 등)는 step `preconditions`.
   - 한 step의 actions를 다른 step이 이어받는다고 가정하지 않는다(평탄화 금지).
2. **저장** — IR과 app-config를 **한 파일로 저장**한다(②가 경로 하나만 받아 둘 다 읽게):
   - 위치: **스킬을 발동한 현재 작업 디렉터리(cwd)** 기준 `output/tas-parse/<source_ticket>.ir.yaml`
     (ticket 없으면 `<test_case_id>.ir.yaml`). 이 repo가 아니라 **사용자가 발동한 cwd 아래**에 저장한다
     — cwd는 `pwd`로 확인. `output/tas-parse/` 디렉터리가 없으면 만든다.
   - 파일 맨 위에 `app:` 블록(app-config 4필드: `sam_app_id`/`flutter_app_id`/`flag_file`/`base_class_name`),
     그 아래에 IR 본문(`test_case_id`…`unresolved`)을 둔다.
3. **출력** — 저장한 파일의 **절대경로**와 내용을 사용자에게 보여준다(다른 cwd에서 ②가 읽을 수 있게 절대경로로).
   "다음 단계 `/tas-appgen`(②)에 이 파일 경로를 넘기면 됩니다"라고 안내.

## 원칙

- **모르는 패턴/정보를 지어내지 말 것.** 식별 단서가 없으면 `unresolved`, app 정보가 없으면 요청.
- **사용자에게 묻는 모든 것(누락값·추가 입력 포함)은 항상 `AskUserQuestion`으로** — 평문 텍스트 질문 금지.
- 위젯 TypeName/property는 ①의 책임이 아니다(②가 앱 소스에서 결정).
