# TAS 스킬 검증 (verification/)

TAS 자동화 4단계(`/tas-parse` → `/tas-appgen` → `/tas-tasgen` → `/tas-verify`)가
**실제로 잘 동작하는지** 확인하는 검증 파일들을 단계별로 모아둔 폴더입니다.

산출물(각 단계의 결과물)은 여기가 아니라 **`output/<stage>/`** 에 따로 저장됩니다.
검증 파일과 산출물을 분리해, 검증 도구를 지워도 산출물은 남도록 했습니다.

```
verification/
├── tas-parse/
│   ├── tas-parse-check.py     # 결정론 체커 (기계 판정)
│   ├── <KEY>.src.txt          # 입력 원문 = 판정 기준(ground truth)
│   └── results.md             # 검증 결과 누적표
└── tas-appgen/
    ├── tas-appgen-check.py    # 결정론 체커 (appgen_output + IR cross-ref)
    └── results.md             # 검증 결과 누적표
                               # (ground truth = output/tas-parse/<KEY>.ir.yaml)
output/
└── <stage>/                  # 그 단계가 만들어낸 산출물 (보존)
    └── <KEY>.<ext>
```

---

## 검증의 기본 원리

검증은 **"기계가 잡을 수 있는 것"과 "사람이 판단할 것"을 나눕니다.**

- **체커(스크립트)** — 객관적·결정론적으로 판정 가능한 것. 같은 입력이면 항상 같은 결과.
- **사람(눈 판정)** — 의미 판단이 필요한 것(누락·맥락·구조). 체커가 대신할 수 없음.

판정의 **근거(ground truth)는 지어내지 않은 고정 문서**여야 합니다. 그래야 "환각"을
검출할 수 있습니다.

---

## 1단계: tas-parse 검증

`/tas-parse`는 **Zephyr TC → semantic IR(YAML)** 변환입니다.
이 단계엔 앱 소스가 없으므로 검증은 **"IR 품질"** 판정입니다.

> IR 구조(2026-06-16~): 각 TC sub-check가 자기완결 `step{id, name, preconditions,
> actions, expected}`. lowered intent는 `actions`, TC 전체 공통 precondition은 top-level.

### 무엇을 근거로 판정하나

| 기준 | 근거(ground truth) | 판정 주체 |
|---|---|---|
| **스키마/불변식** | `../.claude/skills/tas-parse/reference/ir-schema.md` 의 HARD RULES·불변식 | 체커 |
| **환각 없음** | `<KEY>.src.txt` (= `mcp__zephyr-tc__get_tc`로 받은 TC 원문) | 체커 |
| **완전성** | `<KEY>.src.txt` (같은 원문) | 사람 |

### 체커(`tas-parse-check.py`)가 자동으로 잡는 것

스키마/불변식:
- 필수 top 필드(`test_case_id`, `title`, `steps`)
- 각 `step`: `id`(top레벨 1부터 정수 오름차순), `name`(snake_case), `actions`≥1, `expected`≥1
- `actions[].id` = step 안에서 1부터 정수 오름차순 (bool 불가)
- `intent` enum / `key_press`→유효 `key` / `find·focus_move·tap·scroll·read_property`→`target` 필수
- precondition(top+step)·expected `kind` enum, `app_lifecycle` value enum
- `target.match` 는 `text/key/index` 만 — 그 외 키(예: typeName)면 **TypeName 누수**로 FAIL

환각(source_span):
- 모든 precondition/step/expected의 `source_span`이 **TC 원문에 verbatim substring으로 실재**해야 함
  (HTML 제거 + 공백 정규화 후 비교). 없으면 = 지어낸 인용 → FAIL

unresolved:
- `unresolved`가 비어있지 않으면 → ESCALATE

판정:
- `PASS`(0) / `ESCALATE`(2, unresolved 있음) / `FAIL`(1, 위반)

### 사람이 보는 것 (체커가 못 하는 것)

- **완전성**: TC의 모든 step/expected가 누락 없이 IR에 들어갔는지
- **lowering**: "버튼 클릭/선택" → `focus_move`+`key_press OK` 분해가 맞는지
- **구조**: 멀티-시나리오 BAT 티켓을 한 IR로 잘못 평탄화하진 않았는지 등

### 실행 방법

```bash
cd verification/tas-parse
python3 tas-parse-check.py ../../output/tas-parse/<KEY>.ir.yaml <KEY>.src.txt
```

### 한 TC 검증 루프

1. `mcp__zephyr-tc__get_tc(key)` → 원문을 `verification/tas-parse/<KEY>.src.txt`
2. `/tas-parse` 실행 → IR을 `output/tas-parse/<KEY>.ir.yaml`
3. `tas-parse-check.py` 실행 → 스키마/환각 자동 판정
4. 사람이 원문↔IR 대조 → 완전성·구조 판정
5. `results.md`에 종합 기록

결과는 `results.md` 참고.

---

## 2단계: tas-appgen 검증

`/tas-appgen`은 **① IR + 앱 소스 → appgen_output(YAML) + app_test.dart(계측)** 변환입니다.
이 단계는 ①이 미룬 TypeName/find/property를 **앱 `lib/` 소스로 해소**합니다. 따라서 "환각"의
의미가 ①과 다릅니다 — ①은 "TC 원문에 있느냐", ②는 **"앱 소스에 실재하느냐 + IR과 일관되냐"**.

### 무엇을 근거로 판정하나

| 기준 | 근거(ground truth) | 판정 주체 |
|---|---|---|
| **스키마/불변식** | `../.claude/skills/tas-appgen/reference/appgen-schema.md` | 체커 |
| **참조 무결성** | appgen_output 내부 일관성 (typeName↔widgets↔key) | 체커 |
| **IR 대응(xref)·커버리지** | `output/tas-parse/<KEY>.ir.yaml` (= ① 산출 IR) | 체커 |
| **소스 정합성** | 앱 `lib/` 소스 (typeName/필드가 실제로 맞나) | 사람 |

> ②엔 `<KEY>.src.txt`가 없습니다. ②의 ground truth는 **① IR**(구조 대응)과 **앱 소스**(값 정합성)
> 입니다. IR은 기계가 읽을 수 있어 cross-ref·coverage를 자동 판정하고, 소스 정합성만 사람이 봅니다.

### 체커(`tas-appgen-check.py`)가 자동으로 잡는 것

스키마/불변식:
- `app` 블록 필수 필드(`sam_app_id`/`flutter_app_id`/`flag_file`/`base_class_name`)
- `widgets`: `TypeName → [property key,...]` 모양
- 각 binding: action은 `{step_id, action_id, typeName, find}`, expected는 `{step_id, expected_index, kind, ...}` — 둘 중 정확히 하나
- `find.method` enum(`byText/byKey/byTypeName`), `find.value` 존재
- expected `kind`별 필수 필드(app_launch→`appId`, property_value→`key/op/value`, any_present→`options[]`)

참조 무결성:
- 모든 `binding.typeName` ∈ `widgets`
- `property_value.key`, `where`/`options[].where`의 키 ∈ `widgets[typeName]` (= app_test.dart 노출과 일치)

IR 대응(xref):
- 모든 action binding의 `(step_id, action_id)`가 IR에 실재하고 **target intent**(find/focus_move/tap/scroll/read_property)를 가리킴 — `key_press`/`wait` 등 non-target에 binding 부착하면 **FAIL**
- 모든 expected binding의 `(step_id, expected_index)`가 IR에 실재 (dangling ref면 FAIL)

커버리지:
- IR의 모든 target action·expected가 binding되거나 `unsupported`에 있어야 함. 누락(silent drop) → **ESCALATE**

계측(선택, app_test.dart 인자 줄 때):
- `widgets`의 모든 TypeName이 `app_test.dart`에 등록(`to<TypeName>`/printProperties)됐는지, `toStringMap`이 `testWebosApplication`에 연결됐는지

판정:
- `PASS`(0) / `ESCALATE`(2, unsupported 또는 coverage gap) / `FAIL`(1, 스키마·참조·xref·계측 위반)

### 사람이 보는 것 (체커가 못 하는 것)

- **소스 정합성**: binding의 `typeName`·`find.value`·property `key`가 앱 `lib/`의 **실제** 위젯/필드와 맞나 (체커는 내부 일관성만 봄 — 지어낸 위젯이라도 widgets에 같이 등록돼 있으면 통과)
- **find 차원 선택**: byText/byKey/byTypeName 중 그 위젯에 맞는 걸 골랐나
- **계측 정확성**: `to<TypeName>` 매퍼가 읽는 필드가 소스의 진짜 필드인가

### 실행 방법

```bash
cd verification/tas-appgen
python3 tas-appgen-check.py \
  ../../output/tas-appgen/<KEY>.appgen.yaml \
  ../../output/tas-parse/<KEY>.ir.yaml \
  [<app_repo>/integration_test/app_test.dart]   # 선택: 계측 검사
```

결과는 `results.md` 참고.
