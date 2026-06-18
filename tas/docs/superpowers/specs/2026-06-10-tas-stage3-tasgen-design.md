# TAS! Stage ③ — IR + appgen bindings → Python TAS 스크립트 설계

> **skill-only 전환(2026-06-11).** stage③의 **결정론 생성 엔진(`schema/render/gate/tasgen/propparse.py`)
> 과 그 테스트는 제거**됐다(사용자 결정 — ②가 bindings로 다 풀어놓으므로 ③은 슬롯 채우기라,
> 에이전트가 직접 스크립트를 쓴다). 지금 실체 = `/tas-tasgen` 스킬: `reference/tasgen-mapping.md`
> (dispatch 규칙·예시) + `reference/tasbase.py`(primitive 라이브러리). 본 스펙의 **§3 입력 계약과
> §4-4 dispatch 표는 여전히 권위 출처**이고 `tasgen-mapping.md`가 그 에이전트용 이식본이다.
> 아래 §6 Gate A·골든회귀 등 "결정론 엔진/검증" 서술은 더 이상 실행되지 않는 설계 history다.

- 작성일: 2026-06-10
- 단계 네이밍(팀 합의): ① `/tas-parse` → ② `/tas-appgen` → ③ `/tas-tasgen` → ④ `/tas-verify`.
  본 스펙은 **③ `/tas-tasgen`** 이다.
- 선행 스펙: `docs/superpowers/specs/2026-06-09-tas-stage1-parse-design.md` (stage①, IR 정의).
- 범위: ③만. ①은 구현·검증 완료(테스트 36/36). ②는 본 스펙에서 **mock output**으로만 둔다
  (실제 `/tas-appgen` 구현은 별도). ④는 별도 스펙.

## 1. 배경 / 문제

TAS! 워크플로우는 자연어 Zephyr TC를 받아 ① IR로 파싱하고, ② 앱 측 계측(`app_test.dart`
`toStringMap`)을 생성하며, ③ 그 위에서 Python TAS 스크립트를 만들고, ④ 빌드·검증한다.

본 스펙은 **③**, 즉 "이미 풀린 의미(① IR) + 앱 바인딩(② output)을 받아 실제 Python TAS
스크립트를 찍어내는" 단계만 다룬다.

**왜 지금 ②를 건너뛰고 ③부터?** ②(`/tas-appgen`)가 앱 코드를 구현하면 그 결과로 "무엇이
어떤 TypeName·property로 노출되는가"를 기술하는 output이 나온다. ③은 그 output을 소비한다.
따라서 ②의 output 형태(=③의 입력 계약)만 **임의로 고정(mock)** 하면 ③을 먼저 독립적으로
구현·검증할 수 있다. ②는 나중에 그 계약을 채우는 producer로 구현한다.

**TAS 런타임 사실(grounding)**: webOS Flutter 앱의 Python integration-test 프레임워크
(`automation-tests`). 테스트는 `webos.utils.Flutter` 의 `find(byKey|byTypeName|byText)` +
`findAt(index)` 로 위젯을 찾고, `setFocus`/`sendKey`/`tap` 으로 조작하며, `getProperty` 로
상태를 읽는다. `getProperty` 가 반환하는 필드는 ②의 `toStringMap` 이 노출한 것뿐이고, 값은
Dart `Map.toString()` 포맷 문자열(`{key: val, key2: val2}`)이라 파이썬이 `[1:-1]` +
`split(", ")` + `split(": ")` 로 파싱한다. 자세한 API/keyId는 stage① 스펙 부록 A.

## 2. 책임과 경계 (단일 책임)

> **입력: ① IR(semantic, yaml) + ② appgen_output(resolved bindings + 앱 meta + widgets contract).**
> **출력: 얇은 per-TC Python TAS 스크립트(+ 앱당 1개 meta base).**
> **LLM 없음 — 결정론 렌더러. 디바이스/앱 소스를 보지 않는다(④/②의 책임).**

- ③은 "이미 풀린 것을 코드로 실현(render)" 한 가지만 한다. **새 판단·위젯 유추·TypeName
  해석을 하지 않는다** — 그건 전부 ②가 끝낸다(stage① 스펙 §2: *"TypeName/property 해석은
  전부 ②의 책임"*).
- 입력이 구조화돼 있고 출력이 템플릿화되므로 ③은 **완전 결정론**이다. 같은 입력 → 항상 같은
  출력. 이것이 ③을 골든 회귀로 검증 가능하게 만드는 근거다.
- 앱·디바이스가 없어도 단독 동작·단독 검증된다(디바이스 실행은 ④).

## 3. 입력 계약

### 3-1. ① IR (이미 정의됨, stage① 산출물)

stage① 스펙 §3의 semantic IR. 핵심: `steps[]`(순서 보존, `intent`/`key`/`target.match`/
`source_span`), `expected[]`(`kind`/`source_span`), `preconditions[]`. TypeName은 없다.

### 3-2. ② appgen_output (본 스펙에서 mock 고정 = ③의 입력 계약)

②가 IR의 각 semantic target/expected를 concrete하게 **해소(resolve)** 한 결과 + 앱 meta +
widgets contract. ③은 이 bindings를 IR step과 `step_id`로 join한다.

```yaml
app:
  test_label: "Tas Sample"
  flutter_app_id: com.webos.tas.home          # luna service id (flutter TAS)
  sam_app_id: com.webos.app.home              # SAM app id (launch/foreground 확인용)
  package_main: package:home/main.dart         # app_test.dart 의 app.main import
  flag_file: /var/luna/preferences/tas_home_enabled
  jira_id: TVDEVTC-23796                        # 있으면, 없으면 null
  base_class_name: HomeTasBase                  # ③이 생성할 앱 meta base 이름
widgets:                                        # toStringMap 노출분 = getProperty가 줄 수 있는 키
  WAnimatedCarousel: [item_count, group_label]
  Button: [text, semanticsLabel]
  WButton: [label, semanticsLabel, group_label]
  ItemAppLauncherWidget: [id]
bindings:                                       # IR target/expected → concrete
  - step_id: 1                                  # IR.steps[].id 와 join
    typeName: Button
    find: { method: byText, value: "Search" }   # byTypeName|byText|byKey + (index)
  - step_id: 2                                  # key_press 등 target 없는 step은 binding 불필요(생략 가능)
  - expected_index: 0                            # IR.expected[] 와 join
    kind: app_launch
    appId: com.webos.app.voice
  # property 검증 예(home_02):
  # - expected_index: 0
  #   kind: property_value
  #   typeName: WAnimatedCarousel
  #   key: item_count
  #   op: ">="
  #   value: 1
  #   group: HOME_SH_QCARD          # group_label 로 특정 shelf 선택(optional)
unsupported: []                                 # ②가 못 푼 bespoke 부분(루프/셸 등) → ③ escalate
```

**join 규칙**: `bindings[].step_id` ↔ `IR.steps[].id`, `bindings[].expected_index` ↔
`IR.expected[]` 의 0-기반 인덱스. target이 필요 없는 step(`key_press`/`wait`)은 binding을
생략할 수 있다. binding이 IR을 **보강(delta)** 할 뿐 순서·intent·key·source_span은 IR이 진실원천.

## 4. 출력 — 3-layer Python

골든 코퍼스(`automation-tests/Functional/flutter/home/`)의 layering(per-TC 스크립트 → 앱
helper → base)을 유지하되, **fat 로직을 앱별 helper가 아니라 도구가 ship하는 범용 base**로
옮겨 app-agnostic하게 만든다.

```
TasFlutterBase   (도구 ship, 고정, 앱무관, fat)         ← stage3_tasgen/tasbase.py
   ▲
<App>TasBase     (③ 생성, 앱당 1개, meta만)            ← build/tas/<App>TasBase.py
   ▲
<TC>             (③ 생성, TC당, 얇은 run_flutter_test)  ← build/tas/<stem>.py
```

### 4-1. `TasFlutterBase` (도구가 ship — 런타임 산출물)

`automation-tests` 프레임워크 안에서 도는, 앱 무관 결정론 헬퍼. **앱마다 재생성하지 않고
한 번 ship**한다. 모든 앱 공통인 `Map.toString()` 파싱·find·assert primitive를 캡슐화.

```python
class TasFlutterBase(ZephyrTest):
    # 서브클래스가 채우는 meta (클래스 속성)
    FLUTTER_APP_ID = None      # 예: com.webos.tas.home
    SAM_APP_ID = None          # 예: com.webos.app.home
    FLAG_FILE = None
    JIRA_ID = None

    # 셋업: ZephyrTest + Flutter 서비스 확인(flag_file/FLUTTER_APP_ID 사용) + flutter/qml 분기
    # 저수준:
    #   find(typeName=None, by_text=None, by_key=None, index=None)
    #   focus(typeName=None, by_text=None, by_key=None, index=None)   # find + setFocus
    #   send_key(key)            # 'OK'->KEY_ENTER 등 정규화 키 → keyId
    #   tap(...)
    #   get_property()           # getProperty + Map.toString 파싱 → list[dict]
    # 고수준 단언(primitive):
    #   assert_widget_present(typeName, where=None)        # find count>0 (+ where dict 매칭)
    #   assert_any_present([{typeName, where}, ...])       # OR — 하나라도 present면 통과(home_01류)
    #   assert_property(typeName, key, op, value, group=None)
    #   assert_app_launch(appId)                           # foreground/lifecycle 전환 확인
```

> 비고: `tasbase.py` 는 `webos.utils.*`(프레임워크) 의존이라 tas-tool venv에서 **import되지
> 않는다**. 따라서 ③의 Gate A는 이 파일을 **import하지 않고 AST로 메서드명만 내성**한다(§6).

### 4-2. `<App>TasBase` (③ 생성, 앱당 1개)

`app:` meta만 채우는 얇은 서브클래스.

```python
from Functional.flutter._tas.tasbase import TasFlutterBase   # tasbase ship 경로(아래 비고)
class HomeTasBase(TasFlutterBase):
    FLUTTER_APP_ID = 'com.webos.tas.home'
    SAM_APP_ID = 'com.webos.app.home'
    FLAG_FILE = '/var/luna/preferences/tas_home_enabled'
    JIRA_ID = 'TVDEVTC-23796'
```

> **tasbase import 경로**: 생성 스크립트는 `automation-tests` 트리 안에서 실행되므로
> `tasbase.py` 가 거기 고정 경로에 ship돼야 한다. 기본값 `Functional.flutter._tas.tasbase`
> (④ 통합 시 확정). 이 경로는 render의 **파라미터**(`--tasbase-import`, 기본값 위와 같음)로,
> 코드에 하드코딩하지 않는다.

### 4-3. `<TC>` (③ 생성, TC당)

IR steps/expected를 primitive 호출 시퀀스로 1:1 dispatch. 라이선스 헤더 포함.

```python
class GloballineSearch(HomeTasBase):
    def __init__(self):
        self.test_name = 'globalline_search'
        HomeTasBase.__init__(self)
    def run_flutter_test(self):
        self.focus('Button', by_text='Search')          # IR step1 focus_move + binding
        self.send_key('OK')                              # IR step2 key_press
        self.assert_app_launch('com.webos.app.voice')    # IR expected[0] + binding
```

property 예(home_02): `self.assert_property('WAnimatedCarousel', 'item_count', '>=', 1, group='HOME_SH_QCARD')`

### 4-4. IR → primitive dispatch 표 (결정론 규칙)

| IR 요소 | binding | emit |
| --- | --- | --- |
| step `find` | typeName+find | `self.find(typeName, by_*=value[, index])` |
| step `focus_move` | typeName+find | `self.focus(typeName, by_*=value)` |
| step `key_press` (key=OK..) | — | `self.send_key('OK')` |
| step `tap` | typeName+find | `self.focus(...)` → `self.tap()` |
| step `scroll` | — | `self.send_key(<dir>)` 반복 (count는 IR/binding) |
| step `wait` | — | `self.wait(<sec>)` |
| step `read_property` | typeName | `self.get_property()` (검증은 expected에서) |
| expected `app_launch` | appId | `self.assert_app_launch(appId)` |
| expected `widget_visible` | typeName(+where) | `self.assert_widget_present(typeName, where=...)` |
| expected `property_value` | typeName,key,op,value,group | `self.assert_property(...)` |
| expected `state_change`/`navigation` | (조합) | v1 미지원 가능 → §5 escalate |

## 5. 에러 / 경계 처리

- **unsupported/bespoke**: `appgen_output.unsupported` 가 비어있지 않거나, IR에 v1 미지원
  intent/expected(`state_change`/`navigation`)·제어흐름(루프·셸·멀티앱; home_00/04~07류)이
  있으면 → 코드를 추측해 채우지 않고 **escalate**: `run_flutter_test` 에 `NotImplementedError`
  + 사람이 채울 자리 주석 stub을 찍고, 리포트에 사유를 남긴다. (stage① `unresolved` 역할.)
- **binding 누락**: target이 필요한 step(`find`/`focus_move`/`tap`/`scroll`/`read_property`)에
  binding이 없으면 Gate A 실패 → escalate.
- **계약 위반**: binding.typeName ∉ `widgets`, 또는 참조 property key ∉ `widgets[typeName]`,
  또는 emit primitive ∉ `tasbase.py` API → Gate A 하드 실패(메시지와 함께).
- **YAML 파싱 실패 / 필수 필드 누락** → Gate A 실패.

## 6. 검증 — 두 종류로 분리 (런타임 vs 저자 전용)

stage① §4 철학 계승. ③은 결정론이라 **LLM judge가 불필요**하다(생성에 판단이 없으므로
충실도 환각이 발생하지 않음). 대신 결정론 Gate A + 저자 골든 회귀로 충분하다.

| 검증 | answer key | 어디 속하나 | ships? |
|---|---|---|---|
| Gate A — 결정론 스키마/정합/렌더 게이트 | 불필요 | 런타임 파이프라인 | ✅ 항상 |
| 골든 회귀 | 필요(손으로 쓴 ③-스타일 golden) | 저자 eval 하네스 | ❌ |
| negative fixture | 필요(깨진 plan) | 저자 eval 하네스 | ❌ |

### 6-1. Gate A (런타임 ships, 결정론)

1. **입력 스키마**: IR + appgen_output yaml 파싱 OK, 필수 필드 존재, enum 유효.
2. **계약 정합**: 모든 target-step에 binding 존재 & `step_id`/`expected_index` 가 IR에 존재,
   binding.typeName ∈ `widgets`, 참조 property key ∈ `widgets[typeName]`.
3. **primitive 존재**: 렌더가 emit하는 모든 메서드명이 `tasbase.py` 에 실제 정의됨 —
   `tasbase.py` 를 **AST 파싱**해 `def` 이름 집합과 대조(import 불필요, 프레임워크/키 불필요).
4. **출력 유효**: 생성된 Python이 `ast.parse` 통과(문법 유효).

위반 시 하드 실패(사람이 읽는 메시지). escalate(§5)는 실패가 아니라 "사람 확인 필요" 신호.

### 6-2. 저자 eval 하네스 (공유물 미포함)

- **골든 회귀**: 알려진 (IR, appgen_output) → 재생성한 Python == 손으로 쓴 ③-스타일 golden.
  주의: 실제 repo의 home 스크립트는 `has_hero_banner()` 헬퍼 스타일이라 ③ 출력과 **바이트
  일치하지 않는다**. 따라서 golden 타깃은 **③-스타일로 손수 쓴 기대출력**이고, repo 스크립트는
  *동작 동치 참조용*이다(byte-target 아님).
- **negative fixture**: contract에 없는 key 참조, 미존재 primitive, binding 누락 등을 넣은
  plan을 Gate A가 거부하는지.

## 7. 런타임 / 아키텍처

stage① 모듈 관례(`stage1_parse/`)를 따른다. ③은 LLM이 없으므로 `llm/generator/judge/loop`
대신 `schema/render/tasbase/report` 만 둔다.

**패키징(2026-06-11 갱신).** 엔진은 외부 레포 경로 의존을 없애고 **`/tas-tasgen` 스킬 안에
자립형으로 번들**한다(stage①이 `gate_a.py`를 스킬에 번들한 패턴과 통일). 입력은 **JSON 기본
(stdlib)**, PyYAML 있으면 YAML도 허용. 단일 진실원천 = 이 번들. `tests/`는 레포에 남아
`conftest.py`가 번들 경로를 `sys.path`에 추가해 import.

```
.claude/skills/tas-tasgen/   # ── 자립형 번들(스킬=배포 단위) ──
  SKILL.md
  tasgen.py                  # CLI(= /tas-tasgen): --ir IR.json --appgen appgen.json [-o build/tas/] (stdlib; yaml optional)
  stage3_tasgen/             # 결정론 엔진(stdlib only)
    schema.py                # 입력 스키마 + 계약 join (Gate A · dict)
    render.py                # (IR, appgen_output) → Python (템플릿 dispatch)
    gate.py                  # 출력 Gate A (AST 파싱 + primitive∈base 내성)
    report.py                # 결과 리포트(생성 파일 목록 / Gate A / escalate 사유)
    tasbase.py               # ship되는 범용 TasFlutterBase (디바이스로 나가는 런타임 산출물)
    propparse.py             # Map.toString 파서(tasbase의 단위테스트용 트윈)
tests/                       # ── 저자 전용 eval (레포에 잔류, conftest가 번들을 sys.path에) ──
  golden3/                   # (IR, appgen) 입력 + 손으로 쓴 ③-스타일 기대출력 + negative fixtures
  test_{propparse,schema3,gate3,render3,golden3}.py
```

- 결정적 로직(스키마/정합/렌더/AST)은 전부 **순수 Python(stdlib only)**. API 키 불필요,
  디바이스 불필요. → 헤드리스 CI와 CC 스킬(`/tas-tasgen`) 양쪽 충족.
- 산출물: `build/tas/<App>TasBase.py` (앱당 1) + `build/tas/<stem>.py` (TC당). `tasbase.py` 는
  도구에 고정 포함되어 함께 배포된다.

## 8. 비범위

- ② 실제 `/tas-appgen`(app_test.dart 생성) — 여기선 mock output만.
- ④ 빌드·install·실디바이스 실행·되돌림 루프.
- bespoke 제어흐름(루프·셸·멀티앱; home_00/04~07) 코드 생성 — escalate만.
- IR 스키마 변경(제어흐름 도입 등) — 필요 시 stage① 재작업, 본 스펙 밖.

---

## 부록 A — 골든 코퍼스 대응(동작 참조)

| TC | IR 핵심 | ③ 출력(③-스타일) |
| --- | --- | --- |
| home_01 heroBanner | expected widget_visible — **다중 수락조건**(Button text='User Agreements'/'Go to Apps' **또는** SponsoredButton) | binding이 OR 리스트를 줄 때만 `assert_any_present([...])`. 아니면 **escalate**(아래 비고) |
| home_02 qCardList | expected property_value (WAnimatedCarousel item_count>=1, group=HOME_SH_QCARD) | `assert_property('WAnimatedCarousel','item_count','>=',1, group='HOME_SH_QCARD')` |
| home_03 appList | expected property_value (item_count>=1, group=HOME_SH_APPS) | `assert_property(... group='HOME_SH_APPS')` |
| globalline_search | focus_move(Button,text=Search) → key_press(OK) → app_launch(voice) | `focus(...)`→`send_key('OK')`→`assert_app_launch('com.webos.app.voice')` |
| home_00/04~07 | 루프·셸·멀티앱 | **escalate** (v1 미지원) |

**비고 — 다중 수락조건(OR)**: home_01처럼 "A 또는 B 또는 C 중 하나면 통과"는 단일
`assert_widget_present` 로 표현 불가. v1은 두 길만 둔다 — (a) ②가 binding에 **수락조건 OR
리스트**를 주면 ③이 `assert_any_present([{typeName,where}, ...])` primitive로 렌더(이 경우
`assert_any_present` 도 `tasbase.py` 에 포함), (b) 리스트가 없으면 **escalate**. ③이 임의로
조건을 하나로 좁히거나 추측하지 않는다(§2 원칙).
